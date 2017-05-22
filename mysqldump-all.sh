#!/bin/bash
#
#--------------.--------------------------------------------------------
#     .--.     | Welcome to mysqldump-all.sh 
#    |o_o |    | 
#    ||_/ |    | This script will create mysqldumps
#   //   \ \   |  
#  ( | .  | )  | 
# /'\     /'\  | Please report any bugs to: github@stern.koeln
# \__)---(__/  | 
#              | Author: Moritz Stern <github@stern.koeln>
#--------------^--------------------------------------------------------

# change filemask to 0660 for security reasons
umask 066
DATE=$(date +%Y-%m-%d_%H_%M_%S)
TEMPFILE="$( mktemp )"
DATE_YEAR=$(date +%Y)
PID="$$"
SYSLOG_PRE="$(date +%b) $(date +%d) $(date +%T) $(hostname -s) mysqldump[${PID}]: "

# configurable variables
OLD_BACKUP_DIR_TIME=14
PIGZ=$(which pigz)
MYSQL_BIN=$(which mysql)
MYSQLDUMP_BIN=$(which mysqldump)
PATH_TO_DBBACKUP=/var/local/mysqldumps/"${DATE_YEAR}"
MAILTO="github@stern.koeln"
# change to /var/log/messages if necessary
LOGFILE=/var/log/syslog


##########################################################################
#									 #
# 			IMPORTANT INFORMATION				 #
#									 #
# This script only works if you have a ".my.cnf" or "/etc/my.cnf" 	 #
# including super-user and password in order to login to mysql and dump	 #
#									 #
#									 #
##########################################################################

##########################################################################
#									 #
# 		no changes below this line				 #
#									 #
##########################################################################

### system check ####

# make it colourful
red=$(tput setaf 1)
reset=$(tput sgr0)   # \e[0m

type pigz >/dev/null 2>&1 || { echo -e "$red" >&2 "\"pigz\" is not installed. aborting" "$reset" ; exit 1; } 
type mysqldump >/dev/null 2>&1 || { echo -e "$red" >&2 "\"mysqldump\" is not installed. aborting" "$reset" ; exit 1; } 
type mysql >/dev/null 2>&1 || { echo -e "$red" >&2 "\"mysql\" is not installed. aborting" "$reset" ; exit 1; } 

if [ ! -d "${PATH_TO_DBBACKUP}" ]; then
  mkdir -p "${PATH_TO_DBBACKUP}"
  chmod 700 "${PATH_TO_DBBACKUP}"
fi

####################

# change workdir to tmp in case something foes wrong
cd /tmp/

# remove backup-dirs older than OLD_BACKUP_DIR_TIME days
# use exec rm instead of delete as delete does remove recursively
find "${PATH_TO_DBBACKUP}" -maxdepth 1 -type d -mtime +${OLD_BACKUP_DIR_TIME} -exec rm -rf {} \;

# poor mans lockfile
touch /tmp/mysql_backup_running

# get all databases but do not include schema-tables
MYSQL_DB_TO_BACKUP=$( "${MYSQL_BIN}" --batch --skip-column-names -e "SHOW DATABASES" | egrep -v "information_schema|performance_schema" )

# create backup-dir with current date
mkdir -p "${PATH_TO_DBBACKUP}"/"${DATE}"/

# Prevent InnoDB-Buffer-Pool from being filled with Full Table Scans
# http://mysqlopt.blogspot.com/2010/03/innodb-full-table-scan.html
"${MYSQL_BIN}" -e "SET GLOBAL innodb_old_blocks_time=1000;"

# poor mans log
echo "${SYSLOG_PRE}" "MySQL-Dump started" >> "${LOGFILE}" 

# loop for every table
# changed gzip to pigz for faster compression
for i in ${MYSQL_DB_TO_BACKUP} ; do
  MYSQL_TABLE_TO_BACKUP=$( "${MYSQL_BIN}" --batch --skip-column-names -e "USE $i; SHOW TABLES" )
  for j in ${MYSQL_TABLE_TO_BACKUP} ; do
    # do not include dev-db
    if [ "ad${i:(-4)}" != "ad_dev" ]; then
      # dump it
      "${MYSQLDUMP_BIN}"				\
	--events					\
	--ignore-table=mysql.event			\
        --quick						\
        --quote-names					\
        --create-options				\
        --allow-keywords				\
        --force						\
        --add-drop-table				\
        "${i}" "${j}"					\
      2> "${TEMPFILE}"					\
      | "${PIGZ}" -1 -p 16				\
      > "${PATH_TO_DBBACKUP}"/"${DATE}"/"$i"."$j".mysqldump.sql.gz
    else
      # if dev-db only dump the structure
      "${MYSQLDUMP_BIN}"				\
	--events					\
        --ignore-table=mysql.event                      \
        --no-data					\
        --quick						\
        --quote-names					\
        --create-options				\
        --allow-keywords				\
        --force						\
        --add-drop-table				\
        "${i}" "${j}"                                    \
      2> "${TEMPFILE}"                                  \
      | "${PIGZ}" -1 -p 16                              \
      > "${PATH_TO_DBBACKUP}"/"${DATE}"/"$i"."$j".mysqldump.sql.gz
    fi

                                                                                                                  
    # were there any errors? if yes mail it
    test -s "${TEMPFILE}" && {
      echo
      echo " *** mysqldump Fehler bei db: $i table: $j";
      echo
      mail -s "mysqldump-fehler auf $(hostname -s)" "${MAILTO}" < "${TEMPFILE}"
    }
  done

done

# set innodb_old_blocks_time back to normal
"${MYSQL_BIN}" -e "SET GLOBAL innodb_old_blocks_time=0;"

# remove poor mans lockfile
rm -f /tmp/mysql_backup_running
# remove tempfile
rm -f "${TEMPFILE}"
# update date for syslog
SYSLOG_PRE="$(date +%b) $(date +%d) $(date +%T) $(hostname -s) mysqldump[${PID}]: "
# poor mans log
echo "$SYSLOG_PRE" "MySQL-Dump ended" >> "${LOGFILE}" 

#eof
