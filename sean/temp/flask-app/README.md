## 가상 환경 설정 방법

아래 작성된 명령어를 순차적으로 실행

가상 환경 구성이 완료 된 경우 설정한 가상 환경 이름이 앞에 표기 됨
```shell
# 자세한 내용은 실행 환경에 따라 다를 수 있음
(<가상환경 이름>) <user이름>@<user환경> <현재 경로>
```

### 1. 가상 환경 생성
```shell
python -m venv <가상 환경 이름>
```
### 2. 실행 환경에 맞게 다음 명령어 실행
```shell
source env/bin/activate # macOS / Linux

.\env\Scripts\activate # Windows
```
### 3. 가상 환경 내 의존성 설치
```shell
pip install -r requirements.txt
```

## 가상 환경 비활성화

```shell
deactivate
```