

# hypercloud 설치 가이드

## 개요
- 이 브랜치는 __Hypercloud 5.1 릴리즈 기준 브랜치__ 입니다. 이후 업데이트는 최신 브랜치를 참고 바랍니다.
- hypercloud-api-server
	- hypercloud에 필요한 API와 웹훅 및 metering, audit 등의 서비스를 제공하는 서버
- hypercloud-single-operator
	- NamespaceClaim, ResourceQuotaClaim, RoleBindingClaim을 관리하는 오퍼레이터
- hypercloud-multi-operator
	- multi cluster service(단일 클러스터 콘솔에서 여러 클러스터를 관리)를 위한 오퍼레이터
- hypercloud-multi-agent
	- multi cluster의 endpoint 및 resource health check를 위한 리소스

- 이 인스톨러는 __아래에 기술된 각 모듈의 버전 혹은 그 이상의 버전에서만__ 정상 동작이 보장됩니다.
  - hypercloud-api-server:b5.0.34.0
  - hypercloud-single-operator:b5.0.34.0
  - hypercloud-multi-operator:b5.0.34.0

## 구성 요소 및 버전
- hypercloud-api-server
	- image: [tmaxcloudck/hypercloud-api-server:b5.0.34.0](https://hub.docker.com/repository/docker/tmaxcloudck/hypercloud-api-server)
	- git: [https://github.com/tmax-cloud/hypercloud-api-server](https://github.com/tmax-cloud/hypercloud-api-server)
- hypercloud-single-operator
	- image: [tmaxcloudck/hypercloud-single-operator:b5.0.34.0](https://hub.docker.com/repository/docker/tmaxcloudck/hypercloud-single-operator/general)
	- git: [https://github.com/tmax-cloud/hypercloud-single-operator](https://github.com/tmax-cloud/hypercloud-single-operator)
- hypercloud-multi-operator
	- image: [tmaxcloudck/hypercloud-multi-operator:b5.0.34.0](https://hub.docker.com/repository/docker/tmaxcloudck/hypercloud-multi-operator)
	- git: [https://github.com/tmax-cloud/hypercloud-multi-operator](https://github.com/tmax-cloud/hypercloud-multi-operator)
- hypercloud-multi-agent
	- image: [tmaxcloudck/hypercloud-multi-agent:b5.0.25.14](https://hub.docker.com/r/tmaxcloudck/hypercloud-multi-agent)
	- git: [https://github.com/tmax-cloud/hypercloud-multi-agent](https://github.com/tmax-cloud/hypercloud-multi-agent)

## Prerequisite
- 필수 패키지
  - yq, sshpass, kustomize
  - 수동 설치 가이드
    - 버전 설정
	  ```
	  $ YQ_VERSION=v4.5.0
	  $ KUSTOMIZE_VERSION=v3.8.5
	  ```
    - yq
	  ```
	  $ sudo wget https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64 -O /usr/local/bin/yq &&\
      sudo chmod +x /usr/local/bin/yq
	  ```
	- kustomize
	  ```
	  $ sudo curl -L -O "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz"
      $ sudo tar -xzvf "kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz"
      $ sudo chmod +x kustomize
      $ sudo mv kustomize /usr/local/bin/.
      $ sudo rm -f "kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz"
	  ```

- 필수 모듈  
  - [RookCeph](https://github.com/tmax-cloud/hypersds-wiki/)
  - [HyperAuth](https://github.com/tmax-cloud/install-hyperauth)
  - [CertManager](https://github.com/tmax-cloud/install-cert-manager-temp/tree/5.0)

- hypercloud-multi-operator 설치시 필요 모듈  
  - [Ingress](https://github.com/tmax-cloud/install-ingress/tree/5.0)
  - [TemplateServiceBroker](https://github.com/tmax-cloud/install-tsb/tree/tsb-5.0)
  - [CatalogController](https://github.com/tmax-cloud/install-catalog/tree/5.0)
  - [CAPI](https://github.com/tmax-cloud/install-CAPI/tree/5.0)
  - [Federation](https://github.com/tmax-cloud/install-federation/tree/5.0)
  
- hyperauth 사전 작업 (Hypercloud 사용자에 default 그룹 추가)
  - Hypercloud를 서비스할 realm 선택
  - hypercloud5 그룹 생성 (hypercloud5 동일하게 그룹을 생성해야 함)
  ![](https://github.com/tmax-cloud/install-hypercloud/blob/5.0/figure/create-hypercloud5-group.png)
  
  - hypercloud5 그룹을 default로 설정                             
  ![](https://github.com/tmax-cloud/install-hypercloud/blob/5.0/figure/set-hypercloud5-as-default.png)
  
  - client-scope에서 group에 대한 client-scope 생성
  ![](https://github.com/tmax-cloud/install-hypercloud/blob/5.0/figure/create-client-scope.PNG)
  
  - 위에서 만든 client-scope을 hypercloud5 client에 들어가서 추가
  ![](https://github.com/tmax-cloud/install-hypercloud/blob/5.0/figure/add-client-scope.PNG)

## 폐쇄망 구축 가이드
- Dockerhub의 이미지를 사용할 수 없는 경우, 아래의 과정을 통해 이미지를 준비합니다.
- 그 후, hypercloud.config의 REGISTRY의 변수에 이미지 저장소를 넣고 install.sh을 실행하면 됩니다.  
  - 작업 디렉토리 생성 및 환경 설정
    ``` bash
	$ mkdir -p ~/hypercloud-install
	$ export HYPERCLOUD_HOME=~/hypercloud-install
	$ export HPCD_API_SERVER_VERSION=5.0.34.0
	$ export HPCD_SINGLE_OPERATOR_VERSION=5.0.34.0
	$ export HPCD_MULTI_OPERATOR_VERSION=5.0.34.0
	$ export HPCD_MULTI_AGENT_VERSION=5.0.25.14
	$ export HPCD_TIMESCALEDB_VERSION=5.0.0.0
	$ cd $HYPERCLOUD_HOME
	```
  - 외부 네트워크 통신이 가능한 환경에서 이미지 다운로드
    ``` bash
	$ sudo docker pull tmaxcloudck/hypercloud-api-server:b${HPCD_API_SERVER_VERSION}
	$ sudo docker save tmaxcloudck/hypercloud-api-server:b${HPCD_API_SERVER_VERSION} > api-server_b${HPCD_API_SERVER_VERSION}.tar

	$ sudo docker pull gcr.io/kubebuilder/kube-rbac-proxy:v0.5.0
	$ sudo docker save gcr.io/kubebuilder/kube-rbac-proxy:v0.5.0 > kube-rbac-proxy:v0.5.0.tar

	$ sudo docker pull tmaxcloudck/hypercloud-single-operator:b${HPCD_SINGLE_OPERATOR_VERSION}
	$ sudo docker save tmaxcloudck/hypercloud-single-operator:b${HPCD_SINGLE_OPERATOR_VERSION} > single-operator_b${HPCD_SINGLE_OPERATOR_VERSION}.tar

	$ sudo docker pull tmaxcloudck/hypercloud-multi-operator:b${HPCD_MULTI_OPERATOR_VERSION}
	$ sudo docker save tmaxcloudck/hypercloud-multi-operator:b${HPCD_MULTI_OPERATOR_VERSION} > multi-operator_b${HPCD_MULTI_OPERATOR_VERSION}.tar

	$ sudo docker pull tmaxcloudck/timescaledb-cron:b${HPCD_TIMESCALEDB_VERSION}
	$ sudo docker save tmaxcloudck/timescaledb-cron:b${HPCD_TIMESCALEDB_VERSION} > timescaledb-cron_b${HPCD_TIMESCALEDB_VERSION}.tar
	```
  - tar 파일을 폐쇄망 환경으로 이동시킨 후, registry에 이미지 push
    ``` bash
	# 이미지 레지스트리 주소
	$ REGISTRY={IP:PORT}
	
	$ sudo docker load < api-server_b${HPCD_API_SERVER_VERSION}.tar
	$ sudo docker tag tmaxcloudck/hypercloud-api-server:b${HPCD_API_SERVER_VERSION} ${REGISTRY}/tmaxcloudck/hypercloud-api-server:b${HPCD_API_SERVER_VERSION}
	$ sudo docker push ${REGISTRY}/tmaxcloudck/hypercloud-api-server:b${HPCD_API_SERVER_VERSION}

	$ sudo docker load < kube-rbac-proxy:v0.5.0.tar
	$ sudo docker tag gcr.io/kubebuilder/kube-rbac-proxy:v0.5.0 ${REGISTRY}/gcr.io/kubebuilder/kube-rbac-proxy:v0.5.0
	$ sudo docker push ${REGISTRY}/gcr.io/kubebuilder/kube-rbac-proxy:v0.5.0

	$ sudo docker load < single-operator_b${HPCD_SINGLE_OPERATOR_VERSION}.tar
	$ sudo docker tag tmaxcloudck/hypercloud-single-operator:b${HPCD_SINGLE_OPERATOR_VERSION} ${REGISTRY}/tmaxcloudck/hypercloud-single-operator:b${HPCD_SINGLE_OPERATOR_VERSION}
	$ sudo docker push ${REGISTRY}/tmaxcloudck/hypercloud-single-operator:b${HPCD_SINGLE_OPERATOR_VERSION}

	$ sudo docker load < multi-operator_b${HPCD_MULTI_OPERATOR_VERSION}.tar
	$ sudo docker tag tmaxcloudck/hypercloud-multi-operator:b${HPCD_MULTI_OPERATOR_VERSION} ${REGISTRY}/tmaxcloudck/hypercloud-multi-operator:b${HPCD_MULTI_OPERATOR_VERSION}
	$ sudo docker push ${REGISTRY}/tmaxcloudck/hypercloud-multi-operator:b${HPCD_MULTI_OPERATOR_VERSION}

	$ sudo docker load < timescaledb-cron_b${HPCD_TIMESCALEDB_VERSION}.tar
	$ sudo docker tag tmaxcloudck/timescaledb-cron:b${HPCD_TIMESCALEDB_VERSION} ${REGISTRY}/tmaxcloudck/timescaledb-cron:b${HPCD_TIMESCALEDB_VERSION}
	$ sudo docker push ${REGISTRY}/tmaxcloudck/timescaledb-cron:b${HPCD_TIMESCALEDB_VERSION}
	```

## Step 0. hypercloud.config 설정
- 목적 : `hypercloud.config 파일에 설치를 위한 정보 기입`
- 순서 : 
	- 환경에 맞는 config 내용 작성
		- HPCD_MODE
			- single 단일 혹은 single/multi 전부 설치 여부
			- ex) single / multi
		- HPCD_SINGLE_OPERATOR_VERSION
			- hypercloud-single-operator의 버전
			- ex) 5.0.34.0
		- HPCD_MULTI_OPERATOR_VERSION
			- hypercloud-multi-operator의 버전
			- ex) 5.0.34.0
		- HPCD_API_SERVER_VERSION
			- hypercloud-api-server의 버전
			- ex) 5.0.34.0
		- HPCD_TIMESCALEDB_VERSION
			- timescaledb의 버전
			- ex) 5.0.0.0
		- HPCD_MULTI_AGENT_VERSION
			- hypercloud-multi-agent의 버전
			- ex) 5.0.25.14
		- KUBECTL_TIMEOUT
			- 콘솔의 kubectl CLI 기능을 위한 pod 유지 시간(초)
			- ex) 3600 (1시간)
		- REGISTRY
			- 폐쇄망 사용시 image repository의 주소
			- 폐쇄망 아닐시 {REGISTRY} 그대로 유지
			- ex) 192.168.6.171:5000
		- MAIN_MASTER_IP
			- 메인 마스터 노드의 IP
			- ex) 192.168.6.171  
		- INVITATION_TOKEN_EXPIRED_DATE
			- 클러스터에 사용자 초대 시 초대 만료 시간
			- ex) 7days, 1hours, 1minutes
		- KAFKA_ENABLED
			- KAFKA 사용 여부
			- ex) "true", "false"
		- API_SERVER_LOG_LEVEL
			- hypercloud5-api-server의 로그 레벨
			- ex) TRACE, DEBUG, INFO, WARN, ERROR, FATAL
		- SINGLE_OPERATOR_LOG_LEVEL
			- hypercloud-single-operator의 로그 레벨
			- ex) error, info, debug
		- MULTI_OPERATOR_LOG_LEVEL
			- hypercloud-multi-operator의 로그 레벨
			- ex) error, info, debug
		- TIMESCALEDB_LOG_LEVEL
			- timescaledb의 로그 레벨
			- ex) DEBUG5, ..., DEBUG1, INFO, NOTICE, WARNING, ERROR, LOG, FATAL, PANIC
		- TIMESCALEDB_XXX_CHUNK_INTERVAL
		    - XXX 청크 테이블을 나누어 저장할 시간 단위
			- ex) 1days, 1months, 1years
		- TIMESCALEDB_XXX_RETENTION_POLICY
		    - XXX 청크 테이블의 보관 기간 (보관 기간 이후 자동 삭제됨)
			- ex) 1days, 1months, 1years

		`아래 3개 항목은 마스터 노드 다중화 시에만 수정`  
		`메인 마스터 노드를 제외한 마스터 노드들의 정보를 순서에 맞춰 작성`
		- SUB_MASTER_IP
			- 메인 마스터 노드를 제외한 마스터 노드들의 IP 배열
			- ex) ("192.168.6.172" "192.168.6.173")
		- MASTER_NODE_ROOT_USER
			- 메인 마스터 노드를 제외한 마스터 노드의 루트 유저 이름 배열
			- ex) ("root1" "root2")
		- MASTER_NODE_ROOT_PASSWORD
			- 메인 마스터 노드를 제외한 마스터 노드의 패스워드 배열
			- ex ) ("passwd111" "passwd222")

		`아래 2개 항목은 커스텀 도메인 및 콘솔 도메인을 위한 설정`  
		`https://{CONSOLE_SUBDOMAIN}.{CUSTOM_DOMAIN}의 형식으로 사용됨`
		- CUSTOM_DOMAIN
			- 서브 도메인을 제외한 도메인으로 구성  
			- ex) domain.com
		- CONSOLE_SUBDOMAIN
			- 콘솔의 서브 도메인으로 콘솔의 경로를 나타냄   
			- ex) console-subdomain
	

## Step 1. installer 실행
- 목적 : `설치를 위한 shell script 실행`
- 비고 : __kafka가 외부 클러스터에 있다면__ shell script 실행 전 해당 클러스터에서 ca 인증서와 키를 발급 받은 뒤, hypercloud-api-server를 설치하는 클러스터에 hypercloud-kafka-secret을 생성해야 한다.
	1. kafka가 실행되고 있는 클러스터에서 아래 형식을 통해 인증서 발급 받음.  
		```yaml
		apiVersion: cert-manager.io/v1
		kind: Certificate
		metadata:
		  name: hypercloud5-api-server-kafka-cert
		spec:
		  secretName: hypercloud-kafka-secret
		  isCA: false
		  usages:
		  - digital signature
		  - key encipherment
		  - server auth
		  - client auth
		  dnsNames:
		  - "hypercloud.tmaxcloud.org"
		  - "hypercloud5-api-server-service.hypercloud5-system.svc"
		  issuerRef:
		    kind: ClusterIssuer
		    group: cert-manager.io
		    name: tmaxcloud-issuer # 해당 환경의 issuer	
		```
	2. 생성된 secret에서 인증서 추출
		```bash
		$ kubectl get secret hypercloud-kafka-secret -o jsonpath="{['data']['ca\.crt']}" | base64 -d > ca.crt
		$ kubectl get secret hypercloud-kafka-secret -o jsonpath="{['data']['tls\.crt']}" | base64 -d > tls.crt
		$ kubectl get secret hypercloud-kafka-secret -o jsonpath="{['data']['tls\.key']}" | base64 -d > tls.key
		```
	3. 추출한 파일을 이용해 hypercloud-api-server가 설치될 클러스터에 secret 생성
		```bash
		$ kubectl -n hypercloud5-system create secret generic hypercloud-kafka-secret \
	  		--from-file=ca.crt \
  			--from-file=tls.crt \
  			--from-file=tls.key
		```

- 순서 : 
	- 권한 부여 및 실행
		``` bash
		$ sudo chmod +x install.sh
		$ ./install.sh
		```

## 삭제 가이드
- 목적 : `삭제를 위한 shell script 실행`
- 순서 : 
	- 권한 부여 및 실행
		``` bash
		$ sudo chmod +x uninstall.sh
		$ ./uninstall.sh
		```

## multi-operator capi-template version update 가이드
- 목적 : `multi-operator capi-template version update를 위한 shell script실행`
- 순서 :
	- 권한 부여 및 실행
		``` bash
		$ sudo chmod +x update-template.sh
		$ ./update-template.sh
		```
