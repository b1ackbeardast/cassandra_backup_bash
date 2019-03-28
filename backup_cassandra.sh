#!/bin/bash
LOG_FILE="/var/log/backup.log"
exec >>  $LOG_FILE
exec 2>> $LOG_FILE
set -ex
IP=$(hostname -I)
TAG=`date +%Y-%m-%d`
BACKUP_DIR=/data/backups/`hostname`-backup
BACKUP_SCHEMA_DIR="$BACKUP_DIR/schema"
KEYSPACE=`cqlsh $IP -e "DESC KEYSPACES"  | awk '{print $1 "\n" $2 "\n" $3 "\n"}' | grep -v "^$" | sort | sed ':a;N;$!ba;s/\n/\ /g'`
CASSANDRA_DATA=/data/cassandra/data
###### Create/check backup Directory ####
if [ -d  "$BACKUP_SCHEMA_DIR" ]
then
echo "$BACKUP_SCHEMA_DIR already exist"
else
mkdir -p "$BACKUP_SCHEMA_DIR"
fi
## List All Keyspaces on file ##
IP=$(hostname -I)
cqlsh $IP -e "DESC KEYSPACES"  | awk '{print $1 "\n" $2 "\n" $3 "\n"}' | grep -v "^$" | sort > Keyspace_name_schema.cql
## Create directory inside backup SCHEMA directory. As per keyspace name. ##
for i in $(cat Keyspace_name_schema.cql)
do
if [ -d $i ]
then
echo "$i directory exist"
else
mkdir -p $BACKUP_SCHEMA_DIR/$i
fi
done
## Take SCHEMA Backup - All Keyspace and All tables
for VAR_KEYSPACE in $(cat Keyspace_name_schema.cql)
do
cqlsh $IP -e "DESC KEYSPACE  $VAR_KEYSPACE" > "$BACKUP_SCHEMA_DIR/$VAR_KEYSPACE/$VAR_KEYSPACE"_schema.cql 
done

## create snapshot ##
cd $BACKUP_DIR && cd ..

echo creating snapshot $TAG
nodetool snapshot -t $TAG $KEYSPACE

echo sync to backup location $BACKUP_DIR
find $CASSANDRA_DATA -type f -path "*snapshots/$TAG*" -printf %P\\0 | rsync -avP --files-from=- --from0 $CASSANDRA_DATA $BACKUP_DIR

echo tar and rm backup directory
tar -czf `hostname`-`date +%Y-%m-%d`-backup.tar.gz ./`hostname`-backup
rm -rf $BACKUP_DIR

echo removing snapshot $TAG
nodetool clearsnapshot -t $TAG
