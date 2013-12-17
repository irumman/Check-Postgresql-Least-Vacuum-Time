    #!/bin/bash
    # ========================================================================================
    # Postgres least vacuum datenagios check using psql and bash.
    #
    # Author: Rumman
    # This script expects psql to be in the PATH.
    #
    # Usage: ./check_postgres_least_vacuum [-h] [-v][ -H <host> ] [ -P <port> ] [ -U user ] [ -D dbname] [ -x <units> ]
    #                                      [-w <warn_period>] [-c <critical_period>]
    #   -h   --host       host (default 127.0.0.1)
    #   -p   --port       port (default 5432)
    #   -U   --user       database user (default postgres)
    #   -x   --units      units of measurement to display (s = seconds; m = minutes; h = hours; D = days; M = months; Y = year"
    #   -d   --dbname     dbname to connect with postgresql (default postgres)
    #   -w   --warning    warning threshold (default 1 day)
    #   -c   --critical   critical threshold (default 3 days)
    # ========================================================================================



    # Nagios return codes
    STATE_OK=0
    STATE_WARNING=1
    STATE_CRITICAL=2
    STATE_UNKNOWN=3

    # set thresholds in bytes
    WARNING_THRESHOLD=1
    CRITICAL_THRESHOLD=3
    HOST="127.0.0.1"
    PORT=5432
    USER=postgres
    UNITS="D"
    DBNAME=postgres
    DEBUG=0

    echo "working" > /tmp/check_postgres_least_vacuum.tmp
    debug_print() {
      if [ "$DEBUG" -eq 1 ];
      then
        OUTPUT=$1
        echo $OUTPUT
      fi 
    }


    help_print() {
    echo "Postgres least vacuum datenagios check using psql and bash."
    echo ""
    echo "2013 Vantage Labs LLC."
    echo "# This script expects psql to be in the PATH."
    echo ""
    echo "Usage: ./check_postgres_least_vacuum [-h] [-v][ -H <host> ] [ -P <port> ] [ -U user ] [ -D dbname] [ -x <units> ] [-w <warn_period>] [-c <critical_period>]"
    echo " -h   --help       help"
    echo " -v   --verbose    verbose or debug mode"
    echo " -H   --host       host (default 127.0.0.1)"
    echo " -P   --port       port (default 5432)"
    echo " -U   --user       database user (default postgres)"
    echo " -D   --dbname     dbname to connect with postgresql (default postgres)"
    echo " -x   --units      units of measurement to display (s = seconds; m = minutes; h = hours; D = days; M = months; Y = year"
    echo " -w   --warning    warning threshold (default 1 day)"
    echo " -c   --critical   critical threshold (default 3 days)"

    }


    # Parse parameters
    while [ $# -gt 0 ]; do
        case "$1" in
           -h | --help)
                    help_print
                    exit 0;
                    ;;                       
           -v | --verbose)
                    DEBUG=1 
                    ;;      
            -H | --host)
                    shift
                    HOST=$1
                    ;;
            -P | --port)
                    shift
                    PORT=$1
                    ;;
            -U | --user)
                    shift
                    USER=$1
                    ;;
            -D | --dbname)
                    shift
                    DBNAME=$1
                    ;;       
            -x | --unit)
                    shift
                    UNITS=$1
                    ;;
            -w | --warning)
                    shift
                    WARNING_THRESHOLD=$1
                    ;;
            -c | --critical)
                    shift
                    CRITICAL_THRESHOLD=$1
                     ;;
            *)  echo "Unknown argument: $1"
                exit $STATE_UNKNOWN
                ;;
            esac
    shift
    done

    debug_print  "Verbose mode is ON"
    debug_print "HOST=$HOST"
    debug_print "PORT=$PORT"
    debug_print "USER=$USER"
    debug_print "DBNAME=$DBNAME"
    debug_print "UNITS=$UNITS"
    debug_print "WARNING_THRESHOLD=$WARNING_THRESHOLD"
    debug_print "CRITICAL_THRESHOLD=$CRITICAL_THRESHOLD"


    #Check for units
    if [ $UNITS == 's' ];
    then
      let DIV=1
      UNITS="seconds"
    elif   [ $UNITS == 'm' ];
    then
      let DIV=60
      UNITS="minutes"
    elif   [ $UNITS == 'h' ];
    then
      let DIV=60*60
      UNITS="hours"
    elif   [ $UNITS == 'D' ];
    then
      let DIV=60*60*24
      UNITS="days"
    elif   [ $UNITS == 'M' ];
    then
      let DIV=60*60*24*30
      UNITS="months"
    elif   [ $UNITS == 'Y' ];
    then
      let DIV=60*60*24*30*12
      UNITS="years"
    else
      echo "!!!Invaild unit values!!!"
      exit $STATE_UNKNOWN 
    fi 
       
    CURRENT_DATE=`eval date +%Y-%m-%d_%H:%M:%S`
    CURRENT_DATE=`echo "$CURRENT_DATE" | sed -r 's/[_]+/ /g'`
    FINAL_LEAST_VACUUM_DATE=$CURRENT_DATE
    FINAL_LEAST_VACUUM_DATE=`echo "$FINAL_LEAST_VACUUM_DATE" | sed -r 's/[_]+/ /g'`
    FINAL_LEAST_VACUUM_DATE_INT=`date --date="$FINAL_LEAST_VACUUM_DATE" +%s`
    debug_print "Current_date = $FINAL_LEAST_VACUUM_DATE ($FINAL_LEAST_VACUUM_DATE_INT)"



    debug_print "Command = psql -d $DBNAME -U $USER -Atc \"SELECT datname FROM pg_database WHERE datname NOT IN ('postgres')\" -h $HOST -p $PORT"
    GET_DB_LIST=`psql -d $DBNAME -U $USER -Atc "SELECT datname FROM pg_database WHERE datallowconn and NOT datistemplate and datname NOT  IN ('postgres')" -h $HOST -p $PORT`
    if [ $? -gt 0 ];
    then
      echo "ERROR:; can't connect to Postgresql database"
      exit $STATE_UNKNOWN
    fi 

    debug_print  "Database lists = $GET_DB_LIST"
    array=(${GET_DB_LIST// / })
    for i in "${!array[@]}"
    do 
        DBNAME=${array[i]}
        debug_print "Workiing for db = $DBNAME"
        SQL="SELECT min(last_vacuum) FROM pg_stat_all_tables"
       
        LEAST_VACUUM_DATE=`psql -d $DBNAME -U $USER -Atc "$SQL" -h $HOST -p $PORT`
        if [ $? -gt 0 ];
        then
          echo "ERROR:; can't connect to Postgresql database"
          exit $STATE_UNKNOWN
        fi 

       
       
        LEAST_VACUUM_DATE_INT=`date --date="$LEAST_VACUUM_DATE" +%s`
        debug_print "LEAST_VACUUM_DATE = $LEAST_VACUUM_DATE ($LEAST_VACUUM_DATE_INT) "   
        if [ "$LEAST_VACUUM_DATE_INT" -lt "$FINAL_LEAST_VACUUM_DATE_INT" ];
        then
           FINAL_LEAST_VACUUM_DATE=$LEAST_VACUUM_DATE
           FINAL_LEAST_VACUUM_DATE_INT=`date --date="$FINAL_LEAST_VACUUM_DATE" +%s`
        fi  
    done
    debug_print "Least vacuum date for Postgresql db server at $HOST on $PORT $FINAL_LEAST_VACUUM_DATE"


     
    # Calculate xlog diff in bytes
    DIFF=`echo $"(( $(date --date="$CURRENT_DATE" +%s) - $(date --date="$FINAL_LEAST_VACUUM_DATE" +%s) ))/($DIV)"|bc`

    if  [ $DIFF -ge $CRITICAL_THRESHOLD ];
    then
      echo "CRITICAL: Difference between current date ($CURRENT_DATE) and least vacuum date ($FINAL_LEAST_VACUUM_DATE) =  $DIFF $UNITS"
      exit $STATE_CRITICAL
    elif [ $DIFF -ge $WARNING_THRESHOLD ];
    then
      echo "WARNING: Difference between current date ($CURRENT_DATE) and least vacuum date ($FINAL_LEAST_VACUUM_DATE) =  $DIFF $UNITS"
      exit $STATE_WARNING
    else 
      echo "OK: Difference between current date ($CURRENT_DATE) and least vacuum date ($FINAL_LEAST_VACUUM_DATE) =  $DIFF $UNITS"
      exit $STATE_OK
    fi  

 