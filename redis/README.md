## Redis-server 기본 구성

docker network create --gateway 172.24.0.1 --subnet 172.24.0.0/16 redis-network

- **master**: redis-server, redis-sentinel - `172.24.0.2`
- **slave**: redis-server(replicaof master), redis-sentinel - `172.24.0.3`
- **sentinel**: redis-sentinel - `172.24.0.4`
	->  redis-sentinel 홀 수로 구성 (slave -> master 승격 - 과반 수 투표)
- **실제 EC2환경에서는 각 EC2 리전을 다르게 구성할 것 - IDC센터 장애 시 복구, 마스터 승격**

![](https://velog.velcdn.com/images/develing1991/post/961a92bf-4612-4e70-8dd0-15b31467881f/image.png)

## 데이터 타입
**String : 1:1 관계**  
**Lists : 순서존재, Queue와 Stack으로 사용됨**  
**Sets : 순서와 관계없이 저장, 중복불가**  
**Sorted Sets : ZSET 이라고 불리며, Score개념이 존재. Set과 같은데 정렬이 필요한 곳에 쓴다.**  
**Hashes : Field:Value 여러 커플이 존재함. RDB의 Table개념으로 많이 사용함**  

## ZSET 명령어
ZADD : 입력  
ZCARD : Count  
ZRANGE : 정렬순서로 조회  
ZRANGEBYSCORE : score로 함께 조회  
ZREM : 삭제  
ZSCORE : 특정 member의 score를 조회  
ZRANK : 특정 member의 rank를 조회  

### ZSET 테스트


zadd redistest 12000 p0001  
	-> `zadd [key] [score] [value]`  
zcard redistest  
zrange redistest 0 2  
zrange redistest 0 2 withscores  
zrem redistest p0004  
zrangebyscore redistest 50000 110000 withscores  
zscore redistest p0001  
zrank redistest p0001  

![](https://velog.velcdn.com/images/develing1991/post/4d326f81-f854-4e94-af88-b8e19e2b0776/image.png)


<br><br>

## SpringBoot Redis

![](https://velog.velcdn.com/images/develing1991/post/c01b66dd-a266-4b18-8e24-1e7aa2fdd935/image.png)

![](https://velog.velcdn.com/images/develing1991/post/3ba383b2-6144-44ba-861d-38b4ee085706/image.png)

![](https://velog.velcdn.com/images/develing1991/post/ccc4fcb4-44d5-4704-bd16-23f2076ff7e2/image.png)

<br><br>

## score 활용
- 키워드 레벨

| [key] | [value] | [score] |
|---|---|---|
|하기스 | FPG0003 | 1.439 |

- 상품 레벨

| [key] | [value] | [score] |
|---|---|---|
|FPG0003 | ProductUUID | 10000 |


어떻게 보면 double 타입의 score란 개념을 Elastic Search의 점수 만이 아닌  
상품의 금액으로 대입으로도 사용해서 응용 했다고 보면 될듯  

구조는  
쉽게 생각 하면 키워드가 상품의 key를 value로 갖고 있는 구조,,  
나머진 구성한 데이터를 어떻게 가공, 파싱 하느냐에 달림~~  


![](https://velog.velcdn.com/images/develing1991/post/d3bc6d62-35cc-42fd-89de-1555b4a2e553/image.png)

### LowestPriceServiceImpl
```java
@Service
@RequiredArgsConstructor
public class LowestPriceServiceImpl implements LowestPriceService{

    private  final RedisTemplate<String, String> myProductPriceRedis;

    @Override
    public Set getZsetValue(String key) {
        //Set myTempSet = new HashSet();
        return myProductPriceRedis.opsForZSet().rangeWithScores(key, 0, 9);
    }

    @Override
    public Long setNewProduct(Product product) {

        var productUUID = UUID.randomUUID().toString();

        myProductPriceRedis.opsForZSet()
                .add(product.getProductGrpId(), productUUID, product.getPrice());
                // .add(product.getProdGrpId(), product.getProductId(), product.getPrice());

        return myProductPriceRedis.opsForZSet()
                .rank(product.getProductGrpId(), product.getProductId());
    }

    @Override
    public Long setNewProductGrp(ProductGrp productGrp) {
        productGrp.getProductList().forEach(product -> {
            var productUUID = UUID.randomUUID().toString();
            myProductPriceRedis.opsForZSet()
                    .add(productGrp.getProductGrpId(), productUUID, product.getPrice());
                    //.add(productGrp.getProductGrpId(), product.getProductId(), product.getPrice());
        });
        return myProductPriceRedis.opsForZSet().zCard(productGrp.getProductGrpId());
    }

    @Override
    public Long setNewProductKeyword(String keyword, String productGrpId, double score) {
        myProductPriceRedis.opsForZSet().add(keyword, productGrpId, score);
        return myProductPriceRedis.opsForZSet()
                .rank(keyword, productGrpId);
    }

    @Override
    public Keyword getLowestPriceProductByKeyword(String keyword) {
        Keyword keywordInfo = new Keyword();
        List<ProductGrp> productGrpInfo = new ArrayList<>();
        productGrpInfo = getProductGrpUsingKeyword(keyword);
        keywordInfo.setKeyword(keyword);
        keywordInfo.setProductGrpList(productGrpInfo);
        return keywordInfo;
    }

    public List<ProductGrp> getProductGrpUsingKeyword(String keyword){

        List<ProductGrp> productGrpList = new ArrayList<>();

        // elastic search에서 1~2 사이의 값 제공, 많이 매칭 될 수록 2에 가까워짐. ex) 1.12 ... 1.88 ...
        var productGrpIdList
                = List.copyOf(myProductPriceRedis.opsForZSet().reverseRange(keyword, 0, 9)); // 비싼 score 부터 zrevrange


        productGrpIdList.forEach(productGrpId -> {
            var productPriceList
                    = myProductPriceRedis.opsForZSet().rangeWithScores(productGrpId, 0, 9).stream().toList();

            List<Product> productList = new ArrayList<>();

            productPriceList.forEach(productPrice->{
                ObjectMapper objectMapper = new ObjectMapper();
                // [{"value": "UUID"}, {"score": 11000}, ...]
                Map<String, Object> productPriceMap = objectMapper.convertValue(productPrice, Map.class);
                var product = Product.builder()
                                            .productGrpId(productGrpId)
                                            .productId(productPriceMap.get("value").toString())
                                            .price(Double.parseDouble(productPriceMap.get("score").toString()))
                                            .build();
                productList.add(product);
            });

            var productGrp = ProductGrp.builder()
                                            .productGrpId(productGrpId)
                                            .productList(productList)
                                            .build();
            productGrpList.add(productGrp);
        });

        return productGrpList;
    }
}
```

![](https://velog.velcdn.com/images/develing1991/post/b303b25d-74ff-4af4-8db8-aac09238e656/image.png)

## Stress Test
redis-benchmark (참고): http://redisgate.kr/redis/server/redis-benchmark.php

- -n 50000건 요청
- -d 100,000의 데이터 사이즈
- -t hset  hset테스트
- -r 5000 랜덤 키 or 값 범위
- -c 500 동시 접속 클라이언트 수

![](https://velog.velcdn.com/images/develing1991/post/265607a1-a85b-4ad6-859e-d1118c2c1c2d/image.png)

<br><br>

## 장애 대응
### 상황1 (error) READONLY You can't write against a read only replica.
보통 multi redis 환경 구성 시   
마스터(read, write), 슬레이브-레플리카(read), sentinel로 구성을 하게 되는데  
기본적으로 서비스에서는 마스터를 어떤 ip이다 라고 직접 명시하고 서비스를 개발하게 됨  
그 때 어떤 특정 상황에 마스터가 죽고 슬레이브가 마스터로 승격 되었을 때  
슬레이브가 된 마스터를 서비스는 계속 마스터로써 write요청을 하게됨에 따라  
`(error) READONLY You can't write against a read only replica.`  
와 같은 슬레이브 레플리카 노드는 write 할 수 없다는 장애가 발생한다.   
-> 그러므로 서비스에서는 master를 직접 지정하는 것이 아닌 도메인으로 관리  
-> 클라이언트 측 요청에서는 현재 어떤 노드가 마스터인지를 알 수 있기 때문에   


### 상황2 client-output-buffer-limit slave
간혹 어떤 이유에 따라서 마스터와 슬레이브 간의 통신간 sync가 끊어지는 상황이 발생할 수 있음 (예를 들면 네트워크 상황이 좋지 않다던가)  
그렇기에 단순히 데이터를 휘발성 메모리에 저장하는 것이 아닌 마스터가 rdb에 따로 save를 하고  
손실 된 데이터를 동기화 하기위해 슬레이브는 마스터에게 해당 rdb파일을 요청 함  
이 때 주의할 점이 redis configuration에 기본 설정이 256mb이상의 데이터가 한번에 메모리에 올라가거나  
64mb이상의 데이터가 60초 이상 메모리에 올라가면 해당 트랜잭션을 중지하게된다.  
이러한 설정도 제한을 인지하고 슬레이브 쪽 파라미터의 configuration을 변경한 뒤 관리를 해야한다.  
`[client-output-buffer-limit] slave 256mb 64mb 60`  
(음.. 이 장애가 해소된 뒤에 상황1처럼 마스터와 슬레이브의 role이 다시 뒤바 뀔 수도 있지 않을까라는 생각이 드니 master의 configuration도 동일하게 바꿔야 하지 않을까?)  

### 상황3 client-output-buffer-limit normal
이 번에는 마스터, 슬레이브가 아닌 클라이언트 서비스와 redis 간에 발생할 수 있는 상황이다.  
클라이언트가 HGET과 같은 명령어로 큰 해시셋 데이터를 요청하거나(정말 크면 몇기가도 될 수 있음) 또는 HGETALL과 같은 명령어로 모든 해시셋의 데이터를 요청을 했는데  
클라이언트에서 redis로 요청하는 네트워크의 대역대가 변경되어 인바운드 규칙이 어긋 날 수 있는 상황이 있을 수 있음(다이렉트 연결이 아닌 여러 망을 거치기 때문에)  
즉, 클라이언트 서비스에서 요청(아웃바운드)만 가능하고 받는(인바운드)는 타임아웃이 발생하는 현상이 발생할 수 있음  
이 때 redis는 요청을 받았으니 HGET과 HGETALL로 데이터를 뽑아놓고 클라이언트에게 전달해 주지 못하니 버퍼에 저장을 하게 되는데  
보통 클라이언트 서비스의 경우 타임아웃 retry를 하는 경우가 대부분인데  
이런 이유에서 계속해서 요청 받는 redis는 반환하지 못한 데이터를 계속해서 버퍼에 쌓이게 되고  
redis configuration에 설정한 버퍼의 할당 크기(500mb)를 벗어나면 장애가 발생하게 된다.  
이런 데이터가 계속 밀고 들어오게 되면 maxmemory-policy 정책에 의해서 공간 확보를 위해 noevection(메모리가 한계도달 시 더 이상 저장 안함)을 제외한 나머지 정책(volatile-lru, allkey-lru...)들에 의해 기존 데이터를 삭제하게 된다.  
버퍼만 차지하고 데이터는 지워지는 현상이 발생할 수 있음.  
블락을 해제해도 데이터를 지웠으니 반환받지 못하게 될 수 있다.  

`[client-output-buffer-limit] normal 0 0 0`  
따라서 기존 데이터는 지워지면 안되기 때문에  
비록 응답을 못 받더라도 client-output-buffer-limit의 normal의 버퍼 값을 차지할 수 있는 최대 공간을 설정해 주자. 전체 용량의 70% 정도만 차지하게   
물론 장애 상황을 빠르게 인지하고 대응은 해야겠지만..  

### 그 외 장애들
- Client 무한 증가 : redis에서 timeout 설정해도 특정 library에서는 주기적으로 신호를 보내어 idle connection으로 인식되지 않아 close 되지 않는다.  
  	이에 Client 단에서 close를 꼭 해주거나 tcp 를 임의로 kill하는 작업이 필요함. (서드파티로 tcp 커넥션 kill 하는 서버 만들기)  
	(관련 parameter : timeout 21600, maxclient 10000)

- AOF 쓰기작업 : AOF 는 Client 에서 보내는 명령을 모두 hard disk에 기록하는 파일임. (Append Only File).  
	이를 통해 RDB로 한꺼번에 쓰지 않아도 되지만, 너무 빈번하게 발생되는 경우 Redis Service 성능에 영향을 준다. (관련 parameter : appendfsync : everysec ) - 매초 쓰기 사용 시..  
	AOF 쓰기가 너무 오래 걸리는 경우 성능에 문제가 되기도 한다.  
	때문에 대량 쓰기(rdb, aof 생성) 시 fsync를 하지 않도록 설정할 수 있다. (관련 Paramter : no-appendfsync-on-rewrite no)

- KEYS, HGETALL 등 과도한 요청으로 인한 장애 : 전체 데이터를 조회하는 식의 요청은 최대한 지양하는 것이 좋다. (싱글 스레드기 때문에 ...)  
	KEY 명령어는 rename command 를 통해 실행되지 않게 조정할 수 있으며 (이런 전체를 컨트롤 하는 커맨드 삭제), 전체 데이터를 지우는 flushall, flushdb  
	등의 명령어도 제한해 놓는 것이 좋다. (관련 parameter : rename-command keys “”)  

### Redis Server Command

INFO : 현재 Redis 의 전체적인 정보   
SAVE : Disk에 현재 Data기준의 RDB file을 만든다.  
BGSAVE : background에서 SAVE명령을 실행한다.  
BGREWRITEAOF : background 에서 AOF File을 저장한다.  

CONFIGREWRITE : redis.conf 가 아닌 config set 명령을 통해 config를 변경할 수 있는데, 이에 대한 값을 conf file에 저장한다.  
	-> CONFIGREWRITE명령까지 실행 해야 conf file에 저장 됨

CLIENT KILL : 특정 Client의 연결을 해제한다.  
MONITOR : 서버에서 실행되는 명령을 모니터링 한다.  
SLOWLOG : 요청에 대한 수행시간을 기록한다.  
- slowlog-log-slower-than 에 설정된 시간이상의 작업이 발생되었을 시 log로 남긴다. (microsecond 1s = 1000000mcs)  
	-> 키에 너무 많은 값이 있다, 키가 잘못 디자인 되었다 할 때  
- slowlog get # : 해당 개수만큼의 slowlog 를 가져와서 보여준다.  
- slowlog-max-len : 로그를 보관할 리스트 숫자  

LATENCY : 요청에 대한 수행시간을 모니터링 한다. SLOWLOG와 함께 사용된다

### LATENCY를 이용한 모니터링 진단
- `/etc/redis/redis.conf` 설정 변경  
latency-monitor-threshold 0 -> latency-monitor-threshold 100  
테스트를 위해 약 100개 정도 모니터링 데이터를 제한해서 설정  
- 1초간 sleep 실행
- debug sleep 1 
- latency history를 통해 어디서 얼마나 시간이 걸렸는지 확인 가능

![](https://velog.velcdn.com/images/develing1991/post/6da1f0f7-7edf-40bb-acc5-66888352e0eb/image.png)

### 기타 default redis.conf에 따른 장애 ->  기본 값 설정 변경

![](https://velog.velcdn.com/images/develing1991/post/4883bad4-098d-4ced-b9e2-04591420cb97/image.png)

config rewrite // 저장

<br><br>

## GUI tool
참고: https://docs.redis.com/latest/ri/installing/install-ec2/

`completed0728/redis-insight:1.0`

![](https://velog.velcdn.com/images/develing1991/post/dfcb1ac3-33b0-4eff-8747-060a4c9fe383/image.png)

### master-edis 커넥션 추가 및 접속

![](https://velog.velcdn.com/images/develing1991/post/97c6bc3a-027f-4f6f-acbe-32cd0e15f153/image.png)

<br>

- GUI 환경으로 redis를 관리
- configuration이나 redis-cli등을 편리하게 이용할 수 있다.

![](https://velog.velcdn.com/images/develing1991/post/74d15884-9bcf-4765-bf84-a34a5539538b/image.png)

<br>

## 추가 활용 사례

<br>

### 세션 관리 예시 (토큰 만료시간 ttl 옵션 지정)

![](https://velog.velcdn.com/images/develing1991/post/940e5f80-1dca-486e-96b8-040abfa9dba5/image.png)

<br>

### 구글 맵 위경도 거리 계산

참고: https://redis.io/commands/geoadd/

예를 들어 쿠x같이 물류센터가 여러 군데 나뉘어 있을 수 있기 때문에  
사용자의 현재 접속 위경도를 받아서 네이버 지도 같은 map api를 호출해서 가까운 물류센터를 계산해 컨택할 건데  
일정 호출 건이 넘어가면 비용이 들게 되니까..  
redis의 geo활용 사례를 참고해서 위경도 값을 넣어 놓고 관리하는 것도 방법 일듯 하다  

![](https://velog.velcdn.com/images/develing1991/post/7cc297b2-7f3f-4155-b7e4-09744b138306/image.png)
