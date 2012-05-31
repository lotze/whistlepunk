#!/bin/bash

####
## Do before running!
#1) Stop process;
#2) execute on each production box, the archive_distillery_logs.sh command with appropriate arguments (see crontab);
# step 2 should be done by hand, not automated, because we need to check that things ran properly. It probably is best not to run these 
# commands at, or very close to, the same time as the cron job is running as this may cause problems.
#
# At the moment, and forseeable future, act on production logs
RAILS_ENV=production
###

#
if test -f /opt/grockit/share/hadoop/bin/hadoop
then
  HADOOP_BIN=/opt/grockit/share/hadoop/bin/hadoop
fi

if test -f /opt/local/bin/hadoop
then
  HADOOP_BIN=/opt/local/bin/hadoop
fi

if test -d /opt/grockit/metricizer/current
then
  METRICIZER_DIR=/opt/grockit/metricizer/current
fi

if test -d /Users/grockit/workspace/metricizer
then
  METRICIZER_DIR=/Users/grockit/workspace/metricizer
fi

if test -f $METRICIZER_DIR/mapreduce/com.grockit.grockitmetrics-0.0.1-SNAPSHOT-jar-with-dependencies.jar
then
  HADOOP_JAR=$METRICIZER_DIR/mapreduce/com.grockit.grockitmetrics-0.0.1-SNAPSHOT-jar-with-dependencies.jar
fi

if test -f $METRICIZER_DIR/mapreduce/target/com.grockit.grockitmetrics-0.0.1-SNAPSHOT-jar-with-dependencies.jar
then
  HADOOP_JAR=$METRICIZER_DIR/mapreduce/target/com.grockit.grockitmetrics-0.0.1-SNAPSHOT-jar-with-dependencies.jar
fi

TMP_DIR=/tmp/s3_logs/
if test -f /mnt/opt/grockit
then
  TMP_DIR=/mnt/opt/grockit/temp_log_dir/
fi

LOGDIR=/tmp/mapreduce_output
if test -f /opt/grockit/log
then
  LOGDIR=/opt/grockit/log
fi

rm -rf $TMP_DIR
mkdir -p $TMP_DIR/$RAILS_ENV/raw_logs/

s3cmd get --recursive s3://com.grockit.distillery/learnist/production/raw_logs/ $TMP_DIR/$RAILS_ENV/raw_logs
cd $TMP_DIR/$RAILS_ENV/raw_logs

# shouldn't be any staging files there, but get rid of them if there are any...
rm `find ./ -type f |grep staging` #don't need to process staging files. 

$HADOOP_BIN dfs -rmr /learnist
$HADOOP_BIN dfs -put $TMP_DIR /learnist

$HADOOP_BIN jar $HADOOP_JAR com.grockit.analytics.process.RawLogDriver /learnist $RAILS_ENV sorted

$HADOOP_BIN dfs -get /learnist/$RAILS_ENV/sorted $TMP_DIR/$RAILS_ENV/

#copy sorted (ordered) files to metricizer's local file system;
#mkdir -p /opt/grockit/log/
rm $LOGDIR/*.log*
cd $TMP_DIR/$RAILS_ENV/sorted/
mv `find ./ -type f` $LOGDIR
touch $LOGDIR/learnist.log
touch $LOGDIR/learnist.log.old

