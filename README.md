

# hypercloud-operator 설치 가이드

## 구성 요소
* hypercloud-operator
	* image: [https://hub.docker.com/r/tmaxcloudck/hypercloud-operator/tags](https://hub.docker.com/r/tmaxcloudck/hypercloud-operator/tags)
	* git: [https://github.com/tmax-cloud/hypercloud-operator](https://github.com/tmax-cloud/hypercloud-operator)
* hypercloud-webhook 
	* image: [https://hub.docker.com/r/tmaxcloudck/hypercloud-webhook/tags](https://hub.docker.com/r/tmaxcloudck/hypercloud-webhook/tags)
	* git: [https://github.com/tmax-cloud/hypercloud-webhook/tree/java](https://github.com/tmax-cloud/hypercloud-webhook/tree/java)

## Prerequisite
HyperAuth

## 폐쇄망 구축 가이드

설치를 진행하기 전 아래의 과정을 통해 필요한 이미지 및 yaml 파일을 준비한다.
1. **폐쇄망에서 설치하는 경우** 사용하는 image repository에 필요한 이미지를 push한다. 

    * 작업 디렉토리 생성 및 환경 설정
    ```bash
	$ mkdir -p ~/hypercloud-install
	$ export HPCD_HOME=~/hypercloud-install
	$ export HPCD_VERSION=<tag1>
	$ export HPCD_WEBHOOK_VERSION=<tag2>
	$ cd ${HPCD_HOME}

	* <tag1>에는 설치할 hypercloud-operator 버전 명시
		예시: $ export HPCD_VERSION=4.1.4.7
	* <tag2>에는 설치할 hypercloud-webhook 버전 명시
		예시: $ export HPCD_WEBHOOK_VERSION=4.1.0.22
    ```
    * 외부 네트워크 통신이 가능한 환경에서 필요한 이미지를 다운받는다.
    ```bash
	# mysql
	$ sudo docker pull mysql:5.6
	$ sudo docker save mysql:5.6 > mysql_5.6.tar

	# registry: hypercloud에서 private registry 생성 서비스 사용시 필요
	$ sudo docker pull registry:2.6.2
	$ sudo docker save registry:2.6.2 > registry_2.6.2.tar

	# hypercloud-operator
	$ sudo docker pull tmaxcloudck/hypercloud-operator:b${HPCD_VERSION}
	$ sudo docker save tmaxcloudck/hypercloud-operator:b${HPCD_VERSION} > hypercloud-operator_b${HPCD_VERSION}.tar
	
	# hypercloud-webhook
	$ sudo docker pull tmaxcloudck/hypercloud-webhook:b${HPCD_WEBHOOK_VERSION}
	$ sudo docker save tmaxcloudck/hypercloud-webhook:b${HPCD_WEBHOOK_VERSION} > hypercloud-webhook_b${HPCD_WEBHOOK_VERSION}.tar
	
    ```
    * install yaml을 다운로드한다.
    ```bash
    # hypercloud-operator
    $ wget -O hypercloud-operator.tar.gz https://github.com/tmax-cloud/hypercloud-operator/archive/v${HPCD_VERSION}.tar.gz
    
    # hypercloud-webhook
    $ mv hypercloud-webhook-manifest ${HPCD_HOME}/hypercloud-webhook-${HPCD_WEBHOOK_VERSION}
    ```
  
2. 위의 과정에서 생성한 tar 파일들을 `폐쇄망 환경으로 이동`시킨 뒤 사용하려는 registry에 이미지를 push한다.
	* 작업 디렉토리 생성 및 환경 설정
    ```bash
	$ mkdir -p ~/hypercloud-operator-install
	$ export HPCD_HOME=~/hypercloud-operator-install
	$ export HPCD_VERSION=<tag1>
	$ export HPCD_WEBHOOK_VERSION=<tag2>
	$ export REGISTRY=<REGISTRY_IP_PORT>
	$ cd ${HPCD_HOME}

	* <tag1>에는 설치할 hypercloud-operator 버전 명시
		예시: $ export HPCD_VERSION=4.1.4.7
	* <tag2>에는 설치할 hypercloud-webhook 버전 명시
		예시: $ export HPCD_WEBHOOK_VERSION=4.1.0.22
	* <REGISTRY_IP_PORT>에는 폐쇄망 Docker Registry IP:PORT명시
		예시: $ export REGISTRY=192.168.6.110:5000
	```
    * 이미지 load 및 push
    ```bash
    # Load Images
    $ sudo docker load < mysql_5.6.tar
	$ sudo docker load < registry_2.6.2.tar
	$ sudo docker load < hypercloud-operator_b${HPCD_VERSION}.tar
	$ sudo docker load < hypercloud-webhook_b${HPCD_WEBHOOK_VERSION}.tar
    
    # Change Image's Tag For Private Registry
    $ sudo docker tag mysql:5.6 ${REGISTRY}/mysql:5.6
	$ sudo docker tag registry:2.6.2 ${REGISTRY}/registry:2.6.2
	$ sudo docker tag tmaxcloudck/hypercloud-operator:b${HPCD_VERSION} ${REGISTRY}/tmaxcloudck/hypercloud-operator:b${HPCD_VERSION}
	$ sudo docker tag tmaxcloudck/hypercloud-webhook:b${HPCD_WEBHOOK_VERSION} ${REGISTRY}/tmaxcloudck/hypercloud-webhook:b${HPCD_WEBHOOK_VERSION}
    
    # Push Images
    $ sudo docker push ${REGISTRY}/mysql:5.6
	$ sudo docker push ${REGISTRY}/registry:2.6.2
	$ sudo docker push ${REGISTRY}/tmaxcloudck/hypercloud-operator:b${HPCD_VERSION}
	$ sudo docker push ${REGISTRY}/tmaxcloudck/hypercloud-webhook:b${HPCD_WEBHOOK_VERSION}
    ```
## Optional
1.  Nginx Ingress Controller 설치
    * 목적: Hypercloud Operator 내 기능(Reigstry Operator) 사용
    * [Nginx Ingress Controller 설치 가이드] 
        * [https://github.com/tmax-cloud/hypercloud-install-guide/blob/4.1/IngressNginx/shared/README.md](https://github.com/tmax-cloud/hypercloud-install-guide/blob/4.1/IngressNginx/shared/README.md)
2.  Secret Watcher 설치 
    * 목적: Hypercloud Operator 내 기능(Reigstry Operator) 사용
    * [secret-watcher 설치 가이드] 
        * [https://github.com/tmax-cloud/hypercloud-install-guide/tree/4.1/SecretWatcher#secret-watcher-%EC%84%A4%EC%B9%98-%EA%B0%80%EC%9D%B4%EB%93%9C](https://github.com/tmax-cloud/hypercloud-install-guide/tree/4.1/SecretWatcher#secret-watcher-%EC%84%A4%EC%B9%98-%EA%B0%80%EC%9D%B4%EB%93%9C)

## Hypercloud Operator 설치 가이드
1. [1.initialization.yaml 수정](#step-1-1initializationyaml-%EC%8B%A4%ED%96%89)
2. [CRD 적용](h#step-2-crd-%EC%A0%81%EC%9A%A9)
3. [2.mysql-settings.yaml 실행](#step-3-2mysql-settingsyaml-%EC%8B%A4%ED%96%89)
4. [3.mysql-create.yaml 실행](#step-4-3mysql-createyaml-%EC%8B%A4%ED%96%89)
5. [4.hypercloud4-operator.yaml 실행](#step-5-4hypercloud4-operatoryaml-%EC%8B%A4%ED%96%89)

## Step 0. install  yaml 수정
* 목적 : `hypercloud-operator install yaml파일 내용 수정`
* 실행 순서: 
	* 이미지 주소 수정
		```bash
		$ cd ${HPCD_HOME}
		$ tar -xvzf hypercloud-operator.tar.gz

		$ sed -i 's/mysql:5.6/'${REGISTRY}'\/mysql:5.6/g' ${HPCD_HOME}/hypercloud-operator-${HPCD_VERSION}/_yaml_Install/3.mysql-create.yaml
		$ sed -i 's/tmaxcloudck\/hypercloud-operator/'${REGISTRY}'\/tmaxcloudck\/hypercloud-operator/g' ${HPCD_HOME}/hypercloud-operator-${HPCD_VERSION}/_yaml_Install/4.hypercloud4-operator.yaml

		$ sed -i 's/{HPCD_VERSION}/'${HPCD_VERSION}'/g' ${HPCD_HOME}/hypercloud-operator-${HPCD_VERSION}/_yaml_Install/4.hypercloud4-operator.yaml
		```


## Step 1. 1.initialization.yaml 실행
* 목적 : `hypercloud4-system namespace, resourcequota, clusterrole, clusterrolebinding, serviceaccount, configmap 생성`
* 실행 순서: 
	```bash
	$ kubectl apply -f ${HPCD_HOME}/hypercloud-operator-${HPCD_VERSION}/_yaml_Install/1.initialization.yaml
	```

## Step 2. CRD 적용
* 목적 : `hypercloud crd 생성`
* 실행 : *CRD.yaml실행
	```bash
	$ kubectl apply -f ${HPCD_HOME}/hypercloud-operator-${HPCD_VERSION}/_yaml_CRD/${HPCD_VERSION}/Auth/clusterMenuPolicyCRD.yaml
	$ kubectl apply -f ${HPCD_HOME}/hypercloud-operator-${HPCD_VERSION}/_yaml_CRD/${HPCD_VERSION}/Auth/UserSecurityPolicyCRD.yaml
	$ kubectl apply -f ${HPCD_HOME}/hypercloud-operator-${HPCD_VERSION}/_yaml_CRD/${HPCD_VERSION}/Claim/NamespaceClaimCRD.yaml
	$ kubectl apply -f ${HPCD_HOME}/hypercloud-operator-${HPCD_VERSION}/_yaml_CRD/${HPCD_VERSION}/Claim/ResourceQuotaClaimCRD.yaml
	$ kubectl apply -f ${HPCD_HOME}/hypercloud-operator-${HPCD_VERSION}/_yaml_CRD/${HPCD_VERSION}/Claim/RoleBindingClaimCRD.yaml
	$ kubectl apply -f ${HPCD_HOME}/hypercloud-operator-${HPCD_VERSION}/_yaml_CRD/${HPCD_VERSION}/Registry/RegistryCRD.yaml
	$ kubectl apply -f ${HPCD_HOME}/hypercloud-operator-${HPCD_VERSION}/_yaml_CRD/${HPCD_VERSION}/Registry/ImageCRD.yaml
	$ kubectl apply -f ${HPCD_HOME}/hypercloud-operator-${HPCD_VERSION}/_yaml_CRD/${HPCD_VERSION}/Template/TemplateCRD_v1beta1.yaml
	$ kubectl apply -f ${HPCD_HOME}/hypercloud-operator-${HPCD_VERSION}/_yaml_CRD/${HPCD_VERSION}/Template/TemplateInstanceCRD_v1beta1.yaml
	$ kubectl apply -f ${HPCD_HOME}/hypercloud-operator-${HPCD_VERSION}/_yaml_CRD/${HPCD_VERSION}/Template/CatalogServiceClaimCRD_v1beta1.yaml
	```


## Step 3. 2.mysql-settings.yaml 실행
* 목적 : `mysql secret, configmap 생성`
* 실행: 
	```bash
	$ kubectl apply -f ${HPCD_HOME}/hypercloud-operator-${HPCD_VERSION}/_yaml_Install/2.mysql-settings.yaml
	```


## Step 4. 3.mysql-create.yaml 실행
* 목적 : `mysql pvc, deployment, svc 생성`
* 실행: 
	```bash
	$ kubectl apply -f ${HPCD_HOME}/hypercloud-operator-${HPCD_VERSION}/_yaml_Install/3.mysql-create.yaml
	```


## Step 5. 4.hypercloud4-operator.yaml 실행
* 목적: `hypercloud-operator deployment, svc 생성`	
* 실행: 
	```bash
	$ kubectl apply -f ${HPCD_HOME}/hypercloud-operator-${HPCD_VERSION}/_yaml_Install/4.hypercloud4-operator.yaml
	```

## Hypercloud Webhook 설치 가이드
1. [hypercloud4-webhook yaml 수정](#step-5-4hypercloud4-operatoryaml-%EC%8B%A4%ED%96%89)
2. [Secret 생성](#step-5-4hypercloud4-operatoryaml-%EC%8B%A4%ED%96%89)
3. [HyperCloud Webhook Server 배포](#step-5-4hypercloud4-operatoryaml-%EC%8B%A4%ED%96%89)
4. [HyperCloud Webhook Config 생성 및 적용](#step-5-4hypercloud4-operatoryaml-%EC%8B%A4%ED%96%89)
5. [HyperCloud Audit Webhook Config 생성](#step-5-4hypercloud4-operatoryaml-%EC%8B%A4%ED%96%89)
5. [HyperCloud Audit Webhook Config 적용](#step-5-4hypercloud4-operatoryaml-%EC%8B%A4%ED%96%89)

## Step 1. hypercloud4-webhook yaml 수정
* 목적: `hypercloud-webhook yaml에 이미지 정보를 수정`
* 실행: 
    ```bash
    $ sed -i 's/{HPCD_WEBHOOK_VERSION}/'${HPCD_WEBHOOK_VERSION}'/g'  ${HPCD_HOME}/hypercloud-webhook-${HPCD_WEBHOOK_VERSION}/02_webhook-deployment.yaml
    ```

## Step 2. Secret 생성
* 목적: `Hypercloud webhook 서버를 위한 인증서를 Secret으로 생성`
* 실행: 
    ```bash
    $ sh  ${HPCD_HOME}/hypercloud-webhook-${HPCD_WEBHOOK_VERSION}/01_create_secret.sh
    ```

## Step 3. HyperCloud Webhook Server 배포
* 목적: `HyperCloud Webhook의 deployment, service 배포`
* 실행: 
    ```bash
    $ kubectl apply -f  ${HPCD_HOME}/hypercloud-webhook-${HPCD_WEBHOOK_VERSION}/02_webhook-deployment.yaml
    ```

## Step 4. HyperCloud Webhook Config 생성 및 적용
* 목적: `Kube-apiserver와 Webhook 연동 설정 파일 생성 및 적용`
* 실행: 
    ```bash
    $ sh  ${HPCD_HOME}/hypercloud-webhook-${HPCD_WEBHOOK_VERSION}/03_gen-webhook-config.sh
    $ kubectl apply -f  ${HPCD_HOME}/hypercloud-webhook-${HPCD_WEBHOOK_VERSION}/04_webhook-configuration.yaml
    ```

## Step 5.  HyperCloud Audit Webhook Config 생성
* 목적: `Audit Webhook 연동 설정 파일 생성`
* 주의: 마스터 다중화일 경우 모든 마스터에서 진행한다
* 실행: 
    ```bash
    $ sh  ${HPCD_HOME}/hypercloud-webhook-${HPCD_WEBHOOK_VERSION}/05_gen-audit-config.sh
    $ cp  ${HPCD_HOME}/hypercloud-webhook-${HPCD_WEBHOOK_VERSION}/06_audit-webhook-config /etc/kubernetes/pki/audit-webhook-config
    $ cp  ${HPCD_HOME}/hypercloud-webhook-${HPCD_WEBHOOK_VERSION}/07_audit-policy.yaml /etc/kubernetes/pki/audit-policy.yaml
    ```

## Step 6.  HyperCloud Audit Webhook Config 적용
* 목적: `Audit Webhook 연동 설정 파일 적용`
* 주의: 마스터 다중화일 경우 모든 마스터에서 진행한다
* 실행: /etc/kubernetes/manifests/kube-apiserver.yaml을 아래와 같이 수정한다.
   ```bash
   spec.containers.command:
      - --audit-log-path=/var/log/kubernetes/apiserver/audit.log
      - --audit-policy-file=/etc/kubernetes/pki/audit-policy.yaml
      - --audit-webhook-config-file=/etc/kubernetes/pki/audit-webhook-config
   spec.dnsPolicy: ClusterFirstWithHostNet
   ```
	
## Step 7.  test-yaml 배포
* 목적: `Webhook Server 동작 검증`
* 실행: Annotation에 creator/updater/createdTime/updatedTime 필드가 생성 되었는지 확인한다.
  ```bash
  $ kubectl apply -f ${HPCD_HOME}/hypercloud-webhook-${HPCD_WEBHOOK_VERSION}/test-yaml/namespaceclaim.yaml
  $ kubectl describe namespaceclaim example-namespace-webhook
  ```

## 삭제 가이드
