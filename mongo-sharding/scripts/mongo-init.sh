#!/bin/bash

# Инициализация config-server
docker compose exec -T config-server mongosh --port 27017 --quiet <<EOF
rs.initiate(
  {
    _id : "config-server",
       configsvr: true,
    members: [
      { _id : 0, host : "config-server:27017" }
    ]
  }
);
EOF

# Инициализация mongo-shard1
docker compose exec -T mongo-shard1 mongosh --port 27018 --quiet <<EOF
rs.initiate(
  {
    _id : "mongo-shard1",
    members: [
      { _id : 0, host : "mongo-shard1:27018" },
    ]
  }
);
EOF

# Инициализация mongo-shard2
docker compose exec -T mongo-shard2 mongosh --port 27019 --quiet <<EOF
rs.initiate(
  {
    _id : "mongo-shard2",
    members: [
      { _id : 0, host : "mongo-shard2:27019" },
    ]
  }
);
EOF

echo sleep for 5 seconds...
sleep 5

echo init mongos-router
# Инициализация mongos-router и заливка данных
docker compose exec -T mongos-router mongosh --port 27020 --quiet <<EOF
sh.addShard( "mongo-shard1/mongo-shard1:27018");
sh.addShard( "mongo-shard2/mongo-shard2:27019");
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )
use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})
print("Общее количество документов: " + db.helloDoc.countDocuments())
EOF

# выводим количество документов в mongo-shard1
docker compose exec -T mongo-shard1 mongosh --port 27018 --quiet <<EOF
use somedb;
print("Количество документов в shard1: " + db.helloDoc.countDocuments())
EOF

# выводим количество документов в mongo-shard2
docker compose exec -T mongo-shard2 mongosh --port 27019 --quiet <<EOF
use somedb;
print("Количество документов в shard2: " + db.helloDoc.countDocuments())
EOF

