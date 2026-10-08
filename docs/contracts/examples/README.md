# 요청·응답 JSON 예시

명세 문서에 대응하는 실제 JSON 예시를 둡니다. 테스트 데이터로도 씁니다.

- 파일 이름: `<명세>-<동작>-request.json`, `<명세>-<동작>-response.json`
  - 예: `auth-login-request.json`, `auth-login-response.json`
- 오류 응답 예시: `<명세>-error-<상황>.json`
  - 예: `auth-error-login-locked.json`
- 실제 토큰·비밀번호·개인정보는 넣지 않습니다. 필요하면 `"<TOKEN>"` 같은 자리 표시를 씁니다.
- 명세 버전이 바뀌면 예시도 같은 PR에서 고칩니다.
