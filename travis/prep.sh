#!/bin/sh

sleep 15
cassandra-cli --batch < <(echo -e "create keyspace test with placement_strategy = 'org.apache.cassandra.locator.SimpleStrategy' and strategy_options = {replication_factor:1};\nuse test;\ncreate column family dcell;")
