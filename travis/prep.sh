#!/bin/sh

sleep 15

cbf=$(mktemp)
echo "create keyspace test with placement_strategy = 'org.apache.cassandra.locator.SimpleStrategy' and strategy_options = {replication_factor:1};" >> $cbf
echo "use test;" >> $cbf
echo "create column family dcell;" > $cbf
cassandra-cli --batch < $cbf
