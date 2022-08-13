// Copyright 2021 Datafuse Labs.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

use std::borrow::Cow;

use async_trait::async_trait;
use common_datablocks::DataBlock;
use common_datavalues::DataSchemaRef;
use common_datavalues::DataType;
use common_datavalues::TypeDeserializer;
use common_exception::ErrorCode;
use common_exception::Result;
use common_exception::ToErrorCode;
use common_io::prelude::FormatSettings;
use futures::AsyncBufRead;
use futures::AsyncBufReadExt;

use crate::Source;

#[derive(Debug, Clone)]
pub struct NDJsonSourceBuilder {
    schema: DataSchemaRef,
    block_size: usize,
    size_limit: usize,
    format: FormatSettings,
}

impl NDJsonSourceBuilder {
    pub fn create(schema: DataSchemaRef, format: FormatSettings) -> Self {
        NDJsonSourceBuilder {
            schema,
            block_size: 10000,
            size_limit: usize::MAX,
            format,
        }
    }

    pub fn block_size(&mut self, block_size: usize) -> &mut Self {
        self.block_size = block_size;
        self
    }

    pub fn size_limit(&mut self, size_limit: usize) -> &mut Self {
        self.size_limit = size_limit;
        self
    }

    pub fn build<R>(&self, reader: R) -> Result<NDJsonSource<R>>
    where R: AsyncBufRead + Unpin + Send {
        NDJsonSource::try_create(self.clone(), reader, self.format.ident_case_sensitive)
    }
}

pub struct NDJsonSource<R> {
    builder: NDJsonSourceBuilder,
    reader: R,
    rows: usize,
    buffer: String,
    ident_case_sensitive: bool,
}

impl<R> NDJsonSource<R>
where R: AsyncBufRead + Unpin + Send
{
    fn try_create(
        builder: NDJsonSourceBuilder,
        reader: R,
        ident_case_sensitive: bool,
    ) -> Result<Self> {
        Ok(Self {
            builder,
            reader,
            rows: 0,
            buffer: String::new(),
            ident_case_sensitive,
        })
    }
}

fn maybe_truncated(s: &str, limit: usize) -> Cow<'_, str> {
    if s.len() > limit {
        Cow::Owned(format!(
            "(first {}B of {}B): {}",
            limit,
            s.len(),
            &s[..limit]
        ))
    } else {
        Cow::Borrowed(s)
    }
}

#[async_trait]
impl<R> Source for NDJsonSource<R>
where R: AsyncBufRead + Unpin + Send
{
    async fn read(&mut self) -> Result<Option<DataBlock>> {
        // Check size_limit.
        if self.rows >= self.builder.size_limit {
            return Ok(None);
        }

        let mut packs = self
            .builder
            .schema
            .fields()
            .iter()
            .map(|f| f.data_type().create_deserializer(self.builder.block_size))
            .collect::<Vec<_>>();

        let fields = self
            .builder
            .schema
            .fields()
            .iter()
            .map(|f| (f.name(), f.data_type().name()))
            .collect::<Vec<_>>();

        let mut rows = 0;

        loop {
            self.buffer.clear();

            if self
                .reader
                .read_line(&mut self.buffer)
                .await
                .map_err_to_code(ErrorCode::BadBytes, || {
                    format!("Parse NDJson error at line {}", self.rows)
                })?
                == 0
            {
                break;
            }

            if self.buffer.trim().is_empty() {
                continue;
            }

            let mut json: serde_json::Value = serde_json::from_reader(self.buffer.as_bytes())?;

            // if it's not case_sensitive, we convert to lowercase
            if !self.ident_case_sensitive {
                if let serde_json::Value::Object(x) = json {
                    let y = x.into_iter().map(|(k, v)| (k.to_lowercase(), v)).collect();
                    json = serde_json::Value::Object(y);
                }
            }

            for ((name, type_name), deser) in fields.iter().zip(packs.iter_mut()) {
                let value = if self.ident_case_sensitive {
                    &json[name]
                } else {
                    &json[name.to_lowercase()]
                };
                deser.de_json(value, &self.builder.format).map_err(|e| {
                    let value_str = format!("{:?}", value);
                    ErrorCode::BadBytes(format!(
                        "error at row {} column {}: type={}, err={}, value={}",
                        rows,
                        name,
                        type_name,
                        e.message(),
                        maybe_truncated(&value_str, 1024),
                    ))
                })?;
            }

            rows += 1;
            self.rows += 1;

            // Check size_limit.
            if self.rows >= self.builder.size_limit {
                break;
            }

            // Check block_size.
            if rows >= self.builder.block_size {
                break;
            }
        }

        if rows == 0 {
            return Ok(None);
        }

        let series = packs
            .iter_mut()
            .map(|deser| deser.finish_to_column())
            .collect::<Vec<_>>();

        Ok(Some(DataBlock::create(self.builder.schema.clone(), series)))
    }
}