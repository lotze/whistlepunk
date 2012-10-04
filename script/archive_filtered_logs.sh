#!/bin/bash
# dev:  ./archive_filtered_logs.sh /Users/grockit/workspace/whistlepunk/log
# prod: ./archive_filtered_logs.sh /opt/grockit/whistlepunk/current/log

LOGDIR=$1
if [ ! -d $LOGDIR ]; then
  echo "error: source directory '$LOGDIR' does not exist"
  exit 1
fi

if [ -z $NODE_ENV ]; then
  echo "error: NODE_ENV environment variable must be set"
  exit 1
fi

HOSTNAME=`hostname`
TIMESTAMP=`date +%Y%m%d_%H%M%S`

S3_BUCKET="com.grockit.distillery"
VALID_BUCKET_PREFIX=learnist/$NODE_ENV/raw_logs/`date +%Y/%m/%d`
INVALID_BUCKET_PREFIX=learnist/$NODE_ENV/invalid_logs/`date +%Y/%m/%d`

# Note: not currently putting filtered logs into hive (being put in by learnist's archive_distillery_logs.sh)
S3_HIVE_BUCKET="st.learni.analytics"
S3_HIVE_PREFIX="learnist/${NODE_ENV}/raw_logs/ds=$(date +%Y-%m-%d)"

# Set up a temporary logrotate config for the hadoop log file:
cat > /tmp/$TIMESTAMP.logrotate.conf <<HERE
$LOGDIR/*user_events.log {
  daily
  missingok
  notifempty
  rotate 100
  nocompress
  copytruncate
  create
  nomail
}
HERE

# Rotate logs; this will safely move (for example) valid_user_events.log to valid_user_events.log.1
/usr/sbin/logrotate -f --state /tmp/logrotate_state_file /tmp/$TIMESTAMP.logrotate.conf
if [ $? != 0 ]; then
  echo "error: logrotate command failed"
  exit 1
fi

# Rename files to have a standardized timestamp
for f in `ls -1 $LOGDIR/*.log.1`; do
  mv $f $f.$HOSTNAME.$TIMESTAMP || exit 1
done

# Now backup to s3
cd $LOGDIR
for f in `ls -1 valid_user_events.log.1.$HOSTNAME.$TIMESTAMP`; do
  s3cmd put $LOGDIR/$f s3://$S3_BUCKET/$VALID_BUCKET_PREFIX/$f || exit 1
  # s3cmd put $LOGDIR/$f s3://${S3_HIVE_BUCKET}/${S3_HIVE_PREFIX}/$f || exit 1
  bzip2 $LOGDIR/$f || exit 1
done
for f in `ls -1 invalid_user_events.log.1.$HOSTNAME.$TIMESTAMP`; do
  s3cmd put $LOGDIR/$f s3://$S3_BUCKET/$INVALID_BUCKET_PREFIX/$f || exit 1
  # s3cmd put $LOGDIR/$f s3://${S3_HIVE_BUCKET}/${S3_HIVE_PREFIX}/$f || exit 1
  bzip2 $LOGDIR/$f || exit 1
done

