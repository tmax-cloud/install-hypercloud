

# hypercloud 설치 가이드

## 구성 요소
* hypercloud-api-server
	* image: [https://hub.docker.com/repository/docker/tmaxcloudck/hypercloud-api-server](https://hub.docker.com/repository/docker/tmaxcloudck/hypercloud-api-server)
	* git: [https://github.com/tmax-cloud/hypercloud-api-server](https://github.com/tmax-cloud/hypercloud-api-server)
* hypercloud-single-operator
	* image: [https://hub.docker.com/repository/docker/tmaxcloudck/hypercloud-single-operator](https://hub.docker.com/repository/docker/tmaxcloudck/hypercloud-single-operator)
	* git: [https://github.com/tmax-cloud/hypercloud-single-operator](https://github.com/tmax-cloud/hypercloud-single-operator)
* hypercloud-multi-operator
	* image: [https://hub.docker.com/repository/docker/tmaxcloudck/hypercloud-multi-operator](https://hub.docker.com/repository/docker/tmaxcloudck/hypercloud-multi-operator)
	* git: [https://github.com/tmax-cloud/hypercloud-multi-operator](https://github.com/tmax-cloud/hypercloud-multi-operator)
    

## Prerequisite
* 필수 모듈  
  * [RookCeph](https://github.com/tmax-cloud/install-rookceph)
  * [HyperAuth](https://github.com/tmax-cloud/install-hyperauth)

* hypercloud-multi-operator 설치시 필요 모듈  
  * [TemplateServiceBroker](https://github.com/tmax-cloud/install-tsb/tree/tsb-5.0)  
  * [CatalogController](https://github.com/tmax-cloud/install-catalog/tree/5.0)
  * [CAPI](https://github.com/tmax-cloud/install-CAPI/tree/5.0)
  * Federation


## Step 0. hypercloud.config 설정
* 목적 : `hypercloud.config 파일에 설치를 위한 정보 기입`
* 순서: 
	* 환경에 맞는 config 내용 작성
		* HPCD_MODE
			* single만 설치할지, single/multi 전부 설치할지 선택하는 항목
			* ex) single / multi
		* HPCD_SINGLE_OPERATOR_VERSION
			* hypercloud-single-operator의 버전
			* ex) 5.0.0.15
		* HPCD_MULTI_OPERATOR_VERSION
			* hypercloud-multi-operator의 버전
			* ex) 5.0.0.2
		* HPCD_API_SERVER_VERSION
			* hypercloud-api-server의 버전
			* ex) 5.0.0.15
		* HPCD_POSTGRES_VERSION
			* postgres의 버전
			* ex) 5.0.0.1
		* REGISTRY
			* 폐쇄망 사용시 image repository의 주소
			* 폐쇄망 아닐시 {REGISTRY} 그대로 유지
			* ex) 192.168.171:5000
		* MAIN_MASTER_IP
			* 메인 마스터 노드의 IP
			* ex) 192.168.6.171
		* MASTER_NODE_ROOT_PASSWORD
			* 마스터 노드의 패스워드
			* 다중화 마스터의 경우 모두 비밀번호가 동일하다고 가정
		* MASTER_NODE_ROOT_USER
			* 마스터 노드의 루트 유저 이름
			* ex) root

## Step 1. installer 실행
* 목적 : `설치를 위한 shell script 실행`
* 순서: 
	* 권한 부여 및 실행
	``` bash
	$ sudo chmod +x install.sh
	$ ./install.sh
	```

## 삭제 가이드
* 목적 : `삭제를 위한 shell script 실행`
* 순서: 
	* 권한 부여 및 실행
	``` bash
	$ sudo chmod +x uninstall.sh
	$ ./uninstall.sh
	```