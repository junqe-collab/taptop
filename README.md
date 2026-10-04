# Taptop 3층 원정

Godot 4.7.2 일반판 · GDScript · Android 세로 화면 · 2D 정지 캐릭터와 카드.

## 실행

- 웹: https://junqe-collab.github.io/taptop/.
- `main`에 push하면 GitHub Actions가 Godot 4.7.2로 규칙 검사와 웹 빌드를 실행하고 GitHub Pages에 배포한다. Actions의 `Build and deploy web game`에서 수동 재실행도 가능하다.
- 웹 배포는 단일 스레드를 사용하며 개발용 MCP 애드온을 제외한다. 배포 설정은 `.github/workflows/pages.yml`, 웹 프리셋은 `export_presets.cfg`에 있다.

- Windows: [taptop-three-floors.exe](exports/taptop-three-floors.exe)를 실행한다.
- Godot: 이 폴더의 project.godot를 열고 F5로 실행한다.
- Android: [taptop-three-floors.apk](exports/taptop-three-floors.apk)를 휴대폰에 복사해 설치한다. 개인 테스트용 디버그 서명 APK다.
- 소스 버전 0.4.0. 이전 앱과 동일한 패키지 ID를 유지한다.
- 최신 로컬 빌드는 [Windows](exports/0.4.0/taptop-0.4.0.exe), [Android](exports/0.4.0/taptop-0.4.0.apk), `exports/0.4.0/web/`에 있다. 위 루트 exports 경로의 기존 파일은 이전 배포본이다. 공개 웹은 main의 GitHub Actions 배포로 갱신한다.

## 플레이

1. 편성 창에서 레온과 동행할 동료 2명을 선택하고, 이번 시드에 제시된 유물 3개 중 하나를 골라 출발한다.
2. 이벤트·적 구성·전장 특성을 보고 두 경로 중 하나를 선택한다. 위험 경로는 적 강화와 추가 골드를 제공한다.
3. 보급함의 장비를 배분하거나 상점에서 스킬·장비·식량을 구매한다. 제단에서는 스킬을 해제할 수 있다.
4. 적을 눌러 집중 공격 대상을 정하고, 예정 행동과 순서를 보고 카드 하나를 선택한다. 전투당 한 번 손패를 교체할 수 있다(덱에 다른 카드가 있을 때). 행동 시작을 누르면 나머지 캐릭터는 기본 공격한다.
5. 승리하면 드랍 스킬 2개를 차례로 습득하거나 포기한다. 습득 기회는 보관할 수 없다.
6. 식량으로 회복하고 휴식 이벤트를 적용한 뒤 다음 구역으로 이동한다.
7. 3층 최종 보스 전에 레벨 4가 된다. 총 6번 승리하면 완료한다. 전멸하면 원정이 끝난다.

캐릭터 카드를 누르면 능력치·스킬·장비를 확인한다. 파티 덱과 빌드 화면에서 캐릭터별 스킬 구성을 확인할 수 있다. 전투 밖에서는 전열을 변경할 수 있다. 준비부터 결과까지 전체 화면은 스크롤하지 않는다. 긴 정보와 편성·유물·제단은 별도 창 안에서만 스크롤한다.

전투는 전장·행동 순서·손패·실행 버튼을 한 화면에 표시한다. 손패는 좌우로 넘기며 마우스로도 드래그할 수 있다. 캐릭터의 접근, 투사체, 피격 섬광, 피해·회복·방어막 숫자가 실제 행동 결과에 맞춰 재생된다. 상단에서 1배/2배 속도, 기록, 덱을 열 수 있다. 탐색은 갈림길 카드, 상점은 스킬/장비/식량 탭, 보상과 휴식 이벤트는 캐릭터 선택 카드로 표시한다.

스킬 12종, 장비 8종, 동료 후보 4명, 탐색 이벤트 5종과 휴식 이벤트 5종을 제공한다. 유물 6종과 전장 특성 5종을 제공한다. 원정마다 유물·전장 특성·경로·적·상품·드랍·휴식 이벤트·손패·행동 순서가 달라진다. 같은 시드와 같은 선택은 같은 결과를 만든다.

저장·불러오기와 영구 성장은 없다. 종료하면 진행 상황이 사라진다. 수치와 규칙은 [3층 원정 계약](docs/dungeon_run.md)에 기록했다.

## 검증

프로젝트 폴더에서 실행한다. godot은 로컬 Godot 4.7.2 실행 파일을 뜻한다.

~~~text
godot --headless --path . --script res://tests/check_battle.gd
godot --headless --path . --script res://tests/check_depth.gd
godot --headless --path . --script res://tests/check_ui.gd
godot --path . --script res://tests/check_ui.gd -- --capture
godot --path . --script res://tests/check_ui.gd -- --capture --touch --size=360x560
godot --path . --script res://tests/check_feedback.gd
~~~

[검증 결과](docs/verification.md): 기존 규칙 6,525개와 새 시스템 1,023개, 마우스·터치 6전투 전체 진행 및 화면 크기 변경 검사를 통과했다. Android 실기기 검증은 남아 있다. 검증 출력은 기본 `.qa/mobile-depth/`이며 `TAPTOP_QA_DIR`로 위치를 바꿀 수 있다.

내보내기 프리셋은 Web·Windows·Android다. Android는 같은 버전의 내보내기 템플릿, JDK 17, Android SDK가 필요하다. 0.4.0은 `C:/Users/ABC/AppData/Local/Temp/taptop-build-04/` 복사본에서 내보냈으며 MCP 개발 애드온은 배포 파일에 포함하지 않았다. 게임 소스와 에셋 8개 파일의 SHA-256 일치를 확인했다.

## 주요 파일

- game_data.gd: 캐릭터·스킬·장비·몬스터·적 행동·이벤트·유물·전장 특성 데이터.
- 데이터 정의는 이 파일만 수정한다. 효과 처리 규칙은 battle.gd, 이름·설명·아이콘 출력은 화면에서 해당 정의를 읽는다.
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
