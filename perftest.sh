#!/bin/bash

usage() {
  echo "$SCRIPT [OPTIONS] COMMAND"
  echo "  Options "
  echo "    -h : usage "
  echo "    -n : number of files to upload or read"
  echo "    -s : the size of file to operate with "
  echo "    -t : the number of conccurrent thread "
  echo "  COMMAND : the folling commands are available. The bucket which below command work with is named as perftest_\$size "
  echo "    read : read files from a minio server "
  echo "    write : write files into a minio server "
  echo "    clean : clean objects in a bucket. the bucket is named as perftest_\${size} "
}

function bytestohuman {
    # converts a byte count to a human readable format in IEC binary notation (base-1024), rounded to two decimal places for anything larger than a byte. switchable to padded format and base-1000 if desired.
    local L_BYTES="${1:-0}"
    local L_PAD="${2:-no}"
    local L_BASE="${3:-1024}"
    echo $(awk -v bytes="${L_BYTES}" -v pad="${L_PAD}" -v base="${L_BASE}" 'function human(x, pad, base) {
        if(base!=1024)base=1000
        basesuf=(base==1024)?"iB":"B"

        s="BKMGTEPYZ"
        while (x>=base && length(s)>1)
               {x/=base; s=substr(s,2)}
        s=substr(s,1,1)

        xf=(pad=="yes") ? ((s=="B")?"%5d   ":"%8.2f") : ((s=="B")?"%d":"%.2f")
        s=(s!="B") ? (s basesuf) : ((pad=="no") ? s : ((basesuf=="iB")?(s "  "):(s " ")))

        return sprintf( (xf " %s\n"), x, s)
      }
      BEGIN{print human(bytes, pad, base)}')
    return $?
}

function humantobytes {
   echo $1 | awk '{
         ex = index("KMGTPEZY", substr(toupper($1), length($1)))
         val = substr($1, 0, length($1) - 1)
         prod = val * 1024^ex
         sum += prod
      }
      END {print sum}'
   return $?
}


function initMc {
  mc config host add $MC_SITE_ALIAS $ENDPOINT_URL $ACCESS_KEY $SECRET_KEY > /dev/null
}

function cleanBucket {
  mc rm --recursive --force $MC_TARGET_BUCKET > /dev/null
  mc mb $MC_TARGET_BUCKET > /dev/null
}

function printMetric {
  METRIC_OPS=`cat result.log | grep "throughput =" | awk '{ print $8 }'`
  METRIC_TPS=`echo "$METRIC_OPS * $(humantobytes $FILE_SIZE)" | bc`
  echo "t=$THREAD_CNT,s=$FILE_SIZE,op=$1,OPTS=$METRIC_OPS ops, TPS=$(bytestohuman $METRIC_TPS)/s "
}

function perfCheckRead {
  java -jar target/s3pt.jar --accessKey "$ACCESS_KEY" --secretKey "$SECRET_KEY" --endpointUrl $ENDPOINT_URL --usePathStyleAccess --bucketName ${TARGET_BUCKET} -t $THREAD_CNT --number $NUM_FILES_PER_THREAD --size $FILE_SIZE --operation=RANDOM_READ > result.log
  printMetric "read"
}

function perfCheckWrite {
  java -jar target/s3pt.jar --accessKey "$ACCESS_KEY" --secretKey "$SECRET_KEY" --endpointUrl $ENDPOINT_URL --usePathStyleAccess --bucketName ${TARGET_BUCKET} -t $THREAD_CNT --number $NUM_FILES_PER_THREAD --size $FILE_SIZE --operation=UPLOAD > result.log

  printMetric "write"
}

SCRIPT=${0##*/}   # script name

# default value 
ENDPOINT_URL=http://localhost:9000
MC_SITE_ALIAS=perftest
TARGET_BUCKET_PREFIX=perftest
ACCESS_KEY=PH0B4YG9R7AVTW5P5KA1
SECRET_KEY=USntHFFrrxVcssNotuKk8tHj5C4Nq2Dkz8Jpca+r
THREAD_CNT=1
NUM_FILES=1024
FILE_SIZE=256k

# init config for mc client.
initMc
if [ $? != 0 ]; then 
   exit $?
fi

# options
while getopts "h:n:s:t:b:" Arg ; do
  case $Arg in
    h) usage; exit 1 ;;
    n) NUM_FILES=$OPTARG ;;
    s) FILE_SIZE=$OPTARG ;;
    t) THREAD_CNT=$OPTARG ;;
    b) TARGET_BUCKET=$OPTARG ;;
    \?) echo "Invalid option: $OPTARG" >&2 
      exit 1
      ;;
  esac
done
shift "$((OPTIND - 1))"

COMMAND=$1

NUM_FILES_PER_THREAD=`echo "$NUM_FILES / $THREAD_CNT" | bc`

if [ -z $TARGET_BUCKET ]; then
  TARGET_BUCKET="$TARGET_BUCKET_PREFIX-$FILE_SIZE"
fi

MC_TARGET_BUCKET="$MC_SITE_ALIAS/$TARGET_BUCKET"

# create and initialzed a bucket for a performance test
case $COMMAND in
    read) 
        perfCheckRead
        ;;
    write)
        perfCheckWrite
        ;;
    clean) 
        cleanBucket
        ;;
    *)
        usage
        ;;
esac

# java command 

