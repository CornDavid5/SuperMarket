# get path
start_up_path=$(git rev-parse --show-toplevel)/start_up

# start up mysql
docker network create --driver bridge --subnet 192.167.0.0/16 --gateway 192.167.0.1 net-mysql
docker run --name dn1_host1 --restart always --net net-mysql -p 3306:3306 -e MYSQL_ROOT_PASSWORD=root -v $start_up_path/mysql/dn1_host1:/var/lib/mysql -d zongxr/mysql:5.7.37
# each mysql node sleep 1s for the reason that we set second timestamp to server-id
sleep 1s
docker run --name dn1_host2 --restart always --net net-mysql -p 3307:3306 -e MYSQL_ROOT_PASSWORD=root -v $start_up_path/mysql/dn1_host2:/var/lib/mysql -d zongxr/mysql:5.7.37
sleep 1s
docker run --name dn2_host1 --restart always --net net-mysql -p 3308:3306 -e MYSQL_ROOT_PASSWORD=root -v $start_up_path/mysql/dn2_host1:/var/lib/mysql -d zongxr/mysql:5.7.37
sleep 1s
docker run --name dn2_host2 --restart always --net net-mysql -p 3309:3306 -e MYSQL_ROOT_PASSWORD=root -v $start_up_path/mysql/dn2_host2:/var/lib/mysql -d zongxr/mysql:5.7.37
sleep 10s

# exec the DDL
docker exec dn1_host1 mysql -uroot -proot -e "$(cat $start_up_path/mysql/ddl.sql)"
docker exec dn1_host2 mysql -uroot -proot -e "$(cat $start_up_path/mysql/ddl.sql)"
docker exec dn2_host1 mysql -uroot -proot -e "$(cat $start_up_path/mysql/ddl.sql)"
docker exec dn2_host2 mysql -uroot -proot -e "$(cat $start_up_path/mysql/ddl.sql)"

# mount master and slave
dn1_host1_file=$(docker exec dn1_host1 mysql -uroot -proot -e "show master status;" | awk '{print $1}' | tail -n 1)
dn1_host1_pos=$(docker exec dn1_host1 mysql -uroot -proot -e "show master status;" | awk '{print $2}' | tail -n 1)
dn1_host2_file=$(docker exec dn1_host2 mysql -uroot -proot -e "show master status;" | awk '{print $1}' | tail -n 1)
dn1_host2_pos=$(docker exec dn1_host2 mysql -uroot -proot -e "show master status;" | awk '{print $2}' | tail -n 1)
dn2_host1_file=$(docker exec dn2_host1 mysql -uroot -proot -e "show master status;" | awk '{print $1}' | tail -n 1)
dn2_host1_pos=$(docker exec dn2_host1 mysql -uroot -proot -e "show master status;" | awk '{print $2}' | tail -n 1)
dn2_host2_file=$(docker exec dn2_host2 mysql -uroot -proot -e "show master status;" | awk '{print $1}' | tail -n 1)
dn2_host2_pos=$(docker exec dn2_host2 mysql -uroot -proot -e "show master status;" | awk '{print $2}' | tail -n 1)

docker exec dn1_host1 mysql -uroot -proot -e "RESET SLAVE; CHANGE MASTER TO MASTER_HOST='dn1_host2', MASTER_PORT=3306, MASTER_USER='root', MASTER_PASSWORD='root', MASTER_LOG_POS=${dn1_host2_pos}, MASTER_LOG_FILE='"${dn1_host2_file}"';"
docker exec dn1_host2 mysql -uroot -proot -e "RESET SLAVE; CHANGE MASTER TO MASTER_HOST='dn1_host1', MASTER_PORT=3306, MASTER_USER='root', MASTER_PASSWORD='root', MASTER_LOG_POS=${dn1_host1_pos}, MASTER_LOG_FILE='"${dn1_host1_file}"';"
docker exec dn2_host1 mysql -uroot -proot -e "RESET SLAVE; CHANGE MASTER TO MASTER_HOST='dn2_host2', MASTER_PORT=3306, MASTER_USER='root', MASTER_PASSWORD='root', MASTER_LOG_POS=${dn2_host2_pos}, MASTER_LOG_FILE='"${dn2_host2_file}"';"
docker exec dn2_host2 mysql -uroot -proot -e "RESET SLAVE; CHANGE MASTER TO MASTER_HOST='dn2_host1', MASTER_PORT=3306, MASTER_USER='root', MASTER_PASSWORD='root', MASTER_LOG_POS=${dn2_host1_pos}, MASTER_LOG_FILE='"${dn2_host1_file}"';"
docker exec dn1_host1 mysql -uroot -proot -e "show slave status \G start slave;"
docker exec dn1_host2 mysql -uroot -proot -e "show slave status \G start slave;"
docker exec dn2_host1 mysql -uroot -proot -e "show slave status \G start slave;"
docker exec dn2_host2 mysql -uroot -proot -e "show slave status \G start slave;"

# start up mycat
docker run --name mycat --restart always --net net-mysql -p 8066:8066 -p 9066:9066 -v $start_up_path/mycat/conf:/opt/mycat/conf -d zongxr/mycat:1.15.1
sleep 5s

# insert data
docker exec dn1_host1 mysql -uroot -proot -h mycat -P 8066 -e "$(cat $start_up_path/mysql/data.sql)"