# Taptop 3층 원정

Godot 4.7.2 일반판 · GDScript · Android 세로 화면 · 2D 정지 캐릭터와 카드.

## 실행

- Windows: [taptop-three-floors.exe](exports/taptop-three-floors.exe)를 실행한다.
- Godot: 이 폴더의 project.godot를 열고 F5로 실행한다.
- Android: [taptop-three-floors.apk](exports/taptop-three-floors.apk)를 휴대폰에 복사해 설치한다. 개인 테스트용 디버그 서명 APK다.
- 버전 0.3.0. 이전 앱과 동일한 패키지 ID를 유지한다.

## 플레이

1. 레온과 동행할 동료 2명을 선택하고 원정을 시작한다.
2. 이벤트와 적 구성을 보고 두 경로 중 하나를 선택한다. 위험 경로는 적 강화와 추가 골드를 제공한다.
3. 보급함의 장비를 배분하거나 상점에서 스킬·장비·식량을 구매한다. 제단에서는 스킬을 해제할 수 있다.
4. 적의 예정 행동과 순서를 보고 손패에서 카드 하나를 선택한다. 행동 시작을 누르면 나머지 캐릭터는 기본 공격한다.
5. 승리하면 드랍 스킬 2개를 차례로 습득하거나 포기한다. 습득 기회는 보관할 수 없다.
6. 식량으로 회복하고 휴식 이벤트를 적용한 뒤 다음 구역으로 이동한다.
7. 3층 최종 보스 전에 레벨 4가 된다. 총 6번 승리하면 완료한다. 전멸하면 원정이 끝난다.

캐릭터 카드를 누르면 능력치·스킬·장비를 확인한다. 파티 덱과 빌드 화면에서 캐릭터별 스킬 구성을 확인할 수 있다. 전투 밖에서는 전열을 변경할 수 있다. 작은 화면은 세로로 스크롤한다.

전투는 전장·행동 순서·손패·실행 버튼을 한 화면에 표시한다. 손패는 좌우로 넘기며 마우스로도 드래그할 수 있다. 캐릭터의 접근, 투사체, 피격 섬광, 피해·회복·방어막 숫자가 실제 행동 결과에 맞춰 재생된다. 상단에서 1배/2배 속도, 기록, 덱을 열 수 있다. 탐색은 갈림길 카드, 상점은 스킬/장비/식량 탭, 보상과 휴식 이벤트는 캐릭터 선택 카드로 표시한다.

스킬 12종, 장비 8종, 동료 후보 4명, 탐색 이벤트 5종과 휴식 이벤트 5종을 제공한다. 원정마다 경로·적·상품·드랍·휴식 이벤트·손패·행동 순서가 달라진다. 같은 시드와 같은 선택은 같은 결과를 만든다.

저장·불러오기와 영구 성장은 없다. 종료하면 진행 상황이 사라진다. 수치와 규칙은 [3층 원정 계약](docs/dungeon_run.md)에 기록했다.

## 검증

프로젝트 폴더에서 실행한다. godot은 로컬 Godot 4.7.2 실행 파일을 뜻한다.

~~~text
godot --headless --path . --script res://tests/check_battle.gd
godot --headless --path . --script res://tests/check_ui.gd
godot --path . --script res://tests/check_ui.gd -- --capture
godot --path . --script res://tests/check_ui.gd -- --capture --phone --touch
godot --path . --script res://tests/check_feedback.gd
~~~

[검증 결과](docs/verification.md): 6,527개 규칙 검사와 마우스·터치 전체 진행 검사를 통과했다. Android 실기기 검증은 남아 있다. 캡처와 빌드 로그는 .qa/three-floors/에 저장했다.

내보내기 프리셋은 Windows와 Android다. Android는 같은 버전의 내보내기 템플릿, JDK 17, Android SDK가 필요하다. 0.3.0 빌드는 열려 있는 편집기를 유지하기 위해 .tools/export-visual-upgrade 복사본에서 내보냈으며 MCP 개발 애드온은 배포 파일에 포함하지 않았다. 실제 게임 스크립트와 복사본의 해시 일치를 확인했다.

## 주요 파일

- game_data.gd: 캐릭터·스킬·장비·적·이벤트 데이터.
- battle.gd: 원정 상태, 난수, 성장, 획득 제한, 덱, 전투, 휴식.
- main.gd, main.tscn: 화면과 입력.
- dungeon_view.gd: 정지 캐릭터와 층별 배경.
- tests/: 규칙 검사, 자동 플레이 정책, 실제 입력 검사.

## Godot MCP

Godot MCP Toolkit 1.0.2를 사용한다. [연결 설정](docs/mcp_setup.md)을 참고한다.

## 에셋

- Kenney Tiny Dungeon: CC0. 원본 라이선스는 assets/kenney/LICENSE.txt.
- Noto Sans KR: SIL Open Font License 1.1. 원본 라이선스는 assets/fonts/OFL.txt.

기존 이미지 팩과 폰트를 재사용했다. 새 에셋 패키지나 런타임 의존성은 추가하지 않았다.
