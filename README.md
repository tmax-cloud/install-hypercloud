

# hypercloud 설치 가이드

## 구성 요소 및 버전
* hypercloud-api-server
	* image: [tmaxcloudck/hypercloud-api-server:b5.0.5.1](https://hub.docker.com/layers/tmaxcloudck/hypercloud-api-server/b5.0.5.1/images/sha256-f5d66bc5ad9f0d65288bd8f19ff5d4f154c50f8142fa8e792fdad8604bd4a5ca?context=explore)
	* git: [https://github.com/tmax-cloud/hypercloud-api-server](https://github.com/tmax-cloud/hypercloud-api-server)
* hypercloud-single-operator
	* image: [tmaxcloudck/hypercloud-single-operator:b5.0.5.0](https://hub.docker.com/layers/tmaxcloudck/hypercloud-single-operator/b5.0.5.0/images/sha256-fa4082c4d887dca7c0ac5d28eed35a9731e4364ea022c992fec9e19986b2001d?context=explore)
	* git: [https://github.com/tmax-cloud/hypercloud-single-operator](https://github.com/tmax-cloud/hypercloud-single-operator)
* hypercloud-multi-operator
	* image: [tmaxcloudck/hypercloud-multi-operator:b5.0.5.0](https://hub.docker.com/layers/141997981/tmaxcloudck/hypercloud-multi-operator/b5.0.5.0/images/sha256-72af8a7c3fe8dd1bd96c2d0235019528b4dad46b2187db80de5a06f35fcd4374?context=explore)
	* git: [https://github.com/tmax-cloud/hypercloud-multi-operator](https://github.com/tmax-cloud/hypercloud-multi-operator)
    

## Prerequisite
* 필수 모듈  
  * [RookCeph](https://github.com/tmax-cloud/install-rookceph)
  * [HyperAuth](https://github.com/tmax-cloud/install-hyperauth)
  * CertManager

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
		* INVITATION_TOKEN_EXPIRED_DATE
			* 클러스터에 사용자 초대 시 초대 만료 시간
			* ex) 7days, 1hours, 1minutes
	

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
