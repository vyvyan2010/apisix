#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
use t::APISIX 'no_plan';

repeat_each(1);
no_long_string();
no_root_location();
no_shuffle();
log_level("info");

add_block_preprocessor(sub {
    my ($block) = @_;

    if (!$block->request) {
        $block->set_value("request", "GET /t");
    }

    if (!$block->no_error_log && !$block->error_log) {
        $block->set_value("no_error_log", "[error]\n[alert]");
    }
});

run_tests;

__DATA__

=== TEST 1: set upstream(id: 1)
--- config
    location /t {
        content_by_lua_block {
            local t = require("lib.test_admin").test
            local code, body = t('/apisix/admin/upstreams/1',
                 ngx.HTTP_PUT,
                 [[{
                    "nodes": {
                        "127.0.0.1:8080": 1
                    },
                    "type": "roundrobin"
                }]]
                )

            ngx.status = code
            ngx.say(body)
        }
    }
--- error_code: 201
--- response_body
passed



=== TEST 2: add route
--- config
    location /t {
        content_by_lua_block {
            local t = require("lib.test_admin").test
            local code, message = t('/apisix/admin/routes/1',
                ngx.HTTP_PUT,
                [[{
                    "upstream_id": 1,
                    "uri": "/index.html"
                }]]
                )

            if code >= 300 then
                ngx.status = code
                ngx.print(message)
                return
            end

            ngx.say(message)
        }
    }
--- response_body
passed



=== TEST 3: delete upstream(wrong parameter)
--- config
    location /t {
        content_by_lua_block {
            ngx.sleep(0.3)
            local t = require("lib.test_admin").test
            local code, message = t('/apisix/admin/upstreams/1',
                ngx.HTTP_DELETE,
                [[{
                    "force": "wrong"
                }]],
                [[{"action": "delete"}]]
            )
            ngx.print("[delete] code: ", code, " message: ", message)
        }
    }
--- response_body
[delete] code: 400 message: {"error_msg":"the force should be boolean type"}



=== TEST 4: delete upstream(failed)
--- config
    location /t {
        content_by_lua_block {
            ngx.sleep(0.3)
            local t = require("lib.test_admin").test
            local code, message = t('/apisix/admin/upstreams/1',
                ngx.HTTP_DELETE,
                nil,
                [[{"action": "delete"}]]
            )
            ngx.print("[delete] code: ", code, " message: ", message)
        }
    }
--- response_body
[delete] code: 400 message: {"error_msg":"can not delete this upstream, route [1] is still using it now"}



=== TEST 5: delete upstream(use empty table body)
--- config
    location /t {
        content_by_lua_block {
            ngx.sleep(0.3)
            local t = require("lib.test_admin").test
            local code, message = t('/apisix/admin/upstreams/1',
                ngx.HTTP_DELETE,
                [[{
                }]],
                [[{"action": "delete"}]]
            )
            ngx.print("[delete] code: ", code, " message: ", message)
        }
    }
--- response_body
[delete] code: 400 message: {"error_msg":"can not delete this upstream, route [1] is still using it now"}



=== TEST 6: delete upstream(force delete)
--- config
    location /t {
        content_by_lua_block {
            ngx.sleep(0.3)
            local t = require("lib.test_admin").test
            local code, message = t('/apisix/admin/upstreams/1',
                ngx.HTTP_DELETE,
                [[{
                    "force": true
                }]],
                [[{"action": "delete"}]]
            )
            ngx.print("[delete] code: ", code, " message: ", message)
        }
    }
--- response_body chomp
[delete] code: 200 message: passed
