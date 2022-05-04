# postgres 백업 가이드

## Step 0. backup.config 설정
- 목적 : `백업을 위한 정보 기입`
- 순서 : 
	- 환경에 맞는 config 내용 작성
		- backup_file_directory
			- 백업 파일이 존재하는 디렉토리
            - 파일 이름을 제외한 경로만 적어주며 마지막에 '/'는 생략
			- ex) /root/hypercloud5-system
		- origin_ns
			- 백업할 postgres가 존재하는 네임스페이스
			- ex) hypercloud5-system
		- origin_label
			- 백업할 postgres의 label array
			- ex) ("app=postgres", "hypercloud5=db")
		- backup_ns
			- 복원할 postgres가 존재하는 네임스페이스
			- ex) hypercloud5-system
		- backup_label
			- 복원할 postgres의 label array
			- ex) ("app=postgres", "hypercloud5=db")

## Step 1. postgres-backup.sh 실행
- 목적 : `백업/복원을 위한 shell script 실행`
- 백업 :
    ``` bash
    ./postgres-backup.sh backup
    ```
- 복원 : 
    ``` bash
    ./postgres-backup.sh restore
    ```