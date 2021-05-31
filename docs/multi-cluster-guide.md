

# hypercloud multi cluster 사용 가이드

## 사전 작업
* Multi cluster 관련 객체를 생성하기 위해서는 적어도 하나 이상의 네임스페이스를 소유하고 있어야합니다. 네임스페이스는 마스터클러스터 콘솔의 네임스페이스 클레임으로 생성할 수 있습니다. 
	      

## AWS에 클러스터 생성 방법
  Hypercloud에서 일반 사용자는 클러스터를 직접 생성할 수 없습니다. ClusterClaim 객체를 생성함으로써 관리자에게 클러스터를 요청해야합니다.
  관리자가 clusterClaim 객체를 검토하고 승인을 해야 클러스터가 생성 작업이 시작됩니다. 이후부터 사용자는 클러스터 탭에서 클러스터를 조회 할 수 있습니다. 
  * 멀티 클러스터콘솔에서 "클러스터 클레임 생성" 버튼을 클릭합니다. 
 ![](https://github.com/tmax-cloud/install-hypercloud/blob/5.0/figure/multi-cluster-figure/clusterclaim-tab.png)
 
  * 사용할 클러스터의 정보를 입력하고 생성합니다.
 
![](https://github.com/tmax-cloud/install-hypercloud/blob/5.0/figure/multi-cluster-figure/claim-manifest.png)

  * 클러스터클레임의 상태가 Awaiting임을 확인합니다.
![](https://github.com/tmax-cloud/install-hypercloud/blob/5.0/figure/multi-cluster-figure/awaiting.png)
  
  * <관리자로 로그인>하여 사용자의 클러스터클레임 요청을 승인/거절합니다. 
![](https://github.com/tmax-cloud/install-hypercloud/blob/5.0/figure/multi-cluster-figure/approval(3).png)

  * <사용자로 로그인>하여 클러스터클레임의 상태가 Success임을 확인합니다.
![](https://github.com/tmax-cloud/install-hypercloud/blob/5.0/figure/multi-cluster-figure/claim-success.png)

  * 클러스터 탭에서 클러스터의 상태가 Provisioning임을 확인합니다.
![](https://github.com/tmax-cloud/install-hypercloud/blob/5.0/figure/multi-cluster-figure/cluster-provisioning.png)

  * 클러스터 생성에는 10 ~ 20분이 소모됩니다. 클러스터 생성이 완료되면 클러스터의 상태가 Provisioned로 변경됩니다. 
![](https://github.com/tmax-cloud/install-hypercloud/blob/5.0/figure/multi-cluster-figure/cluster-provisioned.png)
