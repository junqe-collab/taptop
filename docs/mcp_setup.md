# Godot MCP Toolkit 연결

적용일: 2026-10-04.

## 설치 구성

| 항목 | 적용 값 |
| --- | --- |
| Godot | 4.7.2 stable 일반판 |
| 애드온 | Godot MCP Toolkit 1.0.2 |
| 서버 패키지 | `@npgamedev/godot-mcp-server@1.0.2` |
| Node.js | 24.18.0 |
| Codex 서버 이름 | `godot_toolkit` |
| 연결 대상 | `D:\workspaces\Projects\project_builder\taptop` |

- 애드온: `taptop/addons/godot_mcp_toolkit/`.
- 서버와 버전 잠금 파일: `project_builder/.tools/godot-mcp/`.
- Codex 등록 위치: `C:\Users\ABC\.codex\config.toml`의 `mcp_servers.godot_toolkit`.
- 사용자 전역 Codex 설정에 등록하며, `GODOT_MCP_PROJECT_PATH`로 대상 프로젝트를 위 경로에 고정한다.
- `GODOT_MCP_CONFIG_VERSION=1`을 사용한다.
- `project.godot`에 플러그인 활성화와 `MCPRuntimeServer` 자동 로드를 등록했다.

서버 실행 명령:

```text
"C:\Program Files\nodejs\node.exe" "D:\workspaces\Projects\project_builder\.tools\godot-mcp\node_modules\@npgamedev\godot-mcp-server\dist\index.js"
```

원본: [Godot MCP Toolkit](https://github.com/NPGameDev/godot-mcp-toolkit), [MCP 서버](https://github.com/NPGameDev/godot-mcp-server).

## 사용 조건

1. Godot에서 `taptop/project.godot`를 연다. 플러그인은 활성화된 상태다.
2. Codex App Server는 저장된 설정으로 `godot_toolkit`에 연결한다. 아래 연결 검사 명령으로 Codex를 통한 실제 도구 호출을 확인할 수 있다.
3. 실행 화면 확인과 입력은 `game_start`로 게임을 실행한 뒤 사용한다. 테스트 후 `game_stop`으로 종료한다.

현재 씬은 실행 중 UI를 생성하므로 `scene_get_tree`는 편집 중인 루트 `Taptop`만 반환한다. 게임 버튼과 상태는 런타임 도구로 조회한다.

`input_simulate`의 `click_node`는 버튼 노드 경로를 사용한다. `click`은 캡처 화면 좌표를 사용한다. 현재 창은 450×900이며 내부 UI 기준 크기는 400×800이므로 노드의 논리 좌표와 캡처 좌표를 구분한다.

## 검증 결과

설치한 서버에 MCP SDK 클라이언트로 연결하여 실제 Godot 편집기와 실행 중인 게임을 검증했다.

- MCP 초기 연결과 기본 도구 36개 조회 성공.
- `scene_get_tree`: `main.tscn`의 `Taptop` 루트 조회 성공.
- `game_start`: `runtime_ready=true` 확인.
- `runtime_screenshot`: 450×900 실행 화면 PNG 캡처 성공.
- `input_simulate`: 원정 시작 → 청동 검 선택 → 전투 진입 성공.
- 화면 좌표 클릭으로 관통 사격 선택. `selected_skill=shot`, `selected_caster=ria` 확인.
- 행동 시작 후 1라운드의 5개 행동 완료. 리아의 마력 6→4, 망령 파수병의 체력 32→11 확인.
- `game_stop` 후 편집기 씬 조회와 플러그인 활성화 설정 조회 성공.
- 기존 `tests/check_battle.gd`: 2,778개 검사 통과, 실패 0개, 200회 전투 시뮬레이션 통과.

## Codex 연결 검증

별도 MCP SDK 검사에 이어, 설치된 Codex 0.160.0의 App Server에서도 다음을 확인했다.

- `initialize`: Codex App Server 초기화 성공.
- `config/mcpServer/reload`: 진단용 App Server에서 설정 다시 읽기 성공.
- `mcpServerStatus/list`: `godot_toolkit` 1.0.2 인식, 도구 36개, `toolsError=null`.
- 대화 기록을 저장하지 않는 임시 세션에서 `mcpServer/tool/call`로 `scene_get_tree` 호출 성공.
- 실제 결과: `res://main.tscn`, 루트 이름 `Taptop`, 타입 `Control`.
- 모델 추론이나 별도 에이전트 작업은 실행하지 않았다.

`project_builder` 폴더에서 실행:

```powershell
& 'C:\Program Files\nodejs\node.exe' '.tools\godot-mcp\codex-connect.mjs'
```

검증 기록은 `.tools/godot-mcp/codex-connection-result.json`에 저장된다. 연결 방식은 [공식 Codex App Server API](https://learn.chatgpt.com/docs/app-server)를 사용한다.

이 검사는 현재 데스크톱 앱과 별도로 실행한 Codex App Server에서 수행했다. 현재 데스크톱 채팅의 직접 도구 목록은 갱신되지 않았다. 실행 중인 채팅을 다른 서버에서 재개하는 요청은 `already has an active writer` 오류로 거부되었다. 기존 채팅의 잠금이나 실행 상태는 변경하지 않았다. 데스크톱 도구 목록 갱신이 필요한 경우 앱의 **설정 → MCP 서버 → Restart**를 사용한다.

이번 작업에서 게임 규칙은 변경하지 않았다. Windows/Android 배포 파일은 다시 빌드하지 않았다. 애드온은 자체 내보내기 처리와 실행 환경 검사로 배포 게임의 MCP 서버 실행을 차단한다.
