import Foundation

/// 앱 화면 계층(View / ViewModel)에서 공통으로 사용하는 최상위 상태 모델입니다.
///
/// 설계 의도:
/// - 각 화면이 개별 문자열/플래그로 상태를 따로 표현하지 않고, 하나의 타입 계약으로 표현합니다.
/// - 상태 전이를 `switch`로 강제해 누락 케이스를 컴파일 타임에 잡을 수 있게 합니다.
/// - `tasks/7. State & Error Policy .md`의 4가지 상태 축(Normal/Loading/Empty/Error)을 코드로 고정합니다.
///
/// 사용 가이드:
/// - ViewModel은 비즈니스 처리 결과를 이 타입으로 변환해 View에 전달합니다.
/// - View는 `switch state`만으로 렌더링 분기(기본 화면, 로딩 UI, empty 안내, 에러 UI)를 결정합니다.
enum AppViewState: Equatable {
    /// 정상 상태
    /// - 로컬 데이터 접근이 가능하고
    /// - 사용자가 핵심 액션(학습/탐색/입력)을 수행할 수 있는 상태입니다.
    case normal

    /// 로딩 상태
    /// - 단순 Bool이 아니라 세부 로딩 맥락(`AppLoadingState`)을 함께 보관합니다.
    /// - 기본값을 `.initialData`로 제공해 호출 측에서 매번 인자를 넣지 않아도 됩니다.
    case loading(AppLoadingState = .initialData)

    /// 빈 상태(데이터/큐 없음)
    /// - 비어있는 이유를 `AppEmptyState`로 구분해 CTA 문구/버튼 정책을 다르게 처리할 수 있습니다.
    case empty(AppEmptyState)

    /// 에러 상태
    /// - 오류의 성격(동기화/저장/손상)을 `AppErrorState`로 구분해 노출 레벨(배너/모달)을 제어합니다.
    case error(AppErrorState)
}

/// 로딩의 세부 원인을 구분하는 타입입니다.
///
/// 목적:
/// - "로딩 중"을 하나로 뭉개지 않고, 초기 진입 로딩과 동기화 로딩을 구분해
///   사용자 메시지와 UI 우선순위를 정확히 제어합니다.
enum AppLoadingState: Equatable {
    /// 앱 진입 직후/복귀 직후 필요한 기본 데이터 로딩 단계
    case initialData

    /// 이미 화면은 진입했지만 백그라운드 동기화가 진행 중인 단계
    case syncing
}

/// Empty 상태의 구체 사유를 정의합니다.
///
/// 정책 연결:
/// - `noWord`: 앱에 학습 단어 자체가 없는 경우 (Import/Add 유도)
/// - `noQueue`: 단어는 있으나 현재 phase 기준으로 처리할 큐가 없는 경우 (다음 행동 유도)
enum AppEmptyState: Equatable {
    /// 학습 단어가 0개인 상태
    case noWord

    /// 단어는 있지만 현재 세션/phase에서 보여줄 큐가 비어있는 상태
    case noQueue
}

/// 앱 레벨 에러의 분류 타입입니다.
///
/// 설계 의도:
/// - 에러를 문자열로 관리하지 않고 타입으로 고정해 분기 누락을 방지합니다.
/// - `isBlocking` 계산 프로퍼티로 UI 차단 여부 정책을 한곳에 모읍니다.
enum AppErrorState: Error, Equatable {
    /// 동기화 실패 (비차단형)
    /// - 일반적으로 로컬 사용은 계속 가능하므로 배너 + 재시도 중심으로 처리합니다.
    case sync

    /// 로컬 저장 실패 (차단 가능)
    /// - 데이터 일관성에 직접 영향이 있어 상황에 따라 모달/차단 처리 대상입니다.
    case save

    /// 데이터 손상/읽기 불가 (치명)
    /// - 핵심 동작 자체가 어려울 수 있어 차단형 대응(복구/초기화 안내)이 필요합니다.
    case dataCorruption

    /// 현재 에러가 "사용자 진행을 즉시 막아야 하는가"를 반환합니다.
    ///
    /// 반환 규칙:
    /// - `sync` -> `false` (비차단, 로컬 계속 사용)
    /// - `save`, `dataCorruption` -> `true` (차단형 대응 필요)
    ///
    /// 주의:
    /// - 이 값은 도메인 정책의 단일 판단 기준이므로, 화면별 임의 오버라이드는 피합니다.
    var isBlocking: Bool {
        switch self {
        case .sync:
            return false
        case .save, .dataCorruption:
            return true
        }
    }
}
