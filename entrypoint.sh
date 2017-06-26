#!/usr/bin/env bash

# you will need these environment vars

#s3fs
#access_key=""
#secret_key=""
#s3_bucket=""
#s3_bucket_path="

# backup
backup_dir="/volume-mount"
#backup_name

function convert_millis {
       	date -d@$1

}

function create_s3fs_password_file () {
	echo "${access_key}:${secret_key}" > ~/.passwd-s3fs
	chmod 600 ~/.passwd-s3fs
}

function mount_s3_bucket {
	s3fs -ouid=0,gid=0,noatime,allow_other,mp_umask=022 ${s3_bucket}:/ /s3-mount
	mkdir -p /s3-mount/${s3_bucket_path}
}

function unmount_s3_bucket {
	fusermount --unmount /s3-mount
}

function parse_host_list {
	export host_list=()
	local file_path=/s3-mount/backup-hosts
	mapfile -t host_list < ${file_path}
}

function parse_host_log_file {
	local host=$1
	local logfile=$2
	local host_log_list=()
	local count=0
	echo ${host_log_list}
	#cat ${logfile}
	echo "[Hostname]: " ${host}
	while IFS='' read -r line || [[ -n ${line} ]];
	do
		log_machine=$(echo ${line} | awk '{ print $1 }')
		log_date=$(echo ${line} | awk '{ print $2 }')
		log_millis=$(echo ${line} | awk '{ print $3 }')
		log_exit_code=$(echo ${line} | awk '{ print $4 }')
		human_time=$(convert_millis ${log_millis})
		if [[ !(${log_exit_code} == 0) ]];
		then
			echo ""
			echo "[OPERATION] [NUMBER]: "${count}" at [TIME]" ${human_time}
			human_time=$(convert_millis ${log_millis})
			echo "[ERROR]    ****!!   Something went wrong    !!****"
			echo "[BEGIN ERROR LOG]"
			cat /s3-mount/${host}/tar-incremental/${log_date}/archive-${log_millis}.error.log
			echo "[END ERROR LOG]"
			echo ""
		else
			echo ""
                        echo "[OPERATION] number: " ${count} " at " ${human_time}
			echo "[SUCCESS]  ****!!   Backup was succesful    !!****"
			echo ""
		fi
		count=${count+1}

	done < ${logfile}
}

function log_add_self_to_host_list {
	cat /s3-mount/backup-hosts > temp-hosts
	sed -i '/'${s3_bucket_path}'/d' temp-hosts
	echo ${s3_bucket_path} >> temp-hosts
	cat temp-hosts > s3-mount/backup-hosts
}

export timestamp=$(date +%s)
export date_today=$(date +%m_%d_%y)

create_s3fs_password_file
mount_s3_bucket
parse_host_list

echo ${host_list}
for host in ${host_list[@]}
do
	system_daily_log="/s3-mount/${host}/tar-incremental/${date_today}/${date_today}-${host}.log"
	host_log=()
	
	if [ -f ${system_daily_log} ] ;then
		parse_host_log_file ${host} ${system_daily_log}
		#mapfile -t host_log <  ${system_daily_log}
		#for line in ${host_log[@]}
		#do
		#	echo ${line} >> test
		#done

	else
		printf ${system_daily_log}" not found\\n"
	fi
done

#echo "sleeping for 10s" && sleep 10
unmount_s3_bucket
