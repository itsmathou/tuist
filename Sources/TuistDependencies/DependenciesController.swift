import TSCBasic
import TuistSupport

// MARK: - Dependencies Controller Errors

public enum DependenciesControllerError: FatalError {
    case unimplemented

    /// Error type.
    public var type: ErrorType {
        switch self {
        case .unimplemented:
            return .abort
        }
    }

    /// Description.
    public var description: String {
        switch self {
        case .unimplemented:
            return "A standard approach for managing third-party dependencies is being worked on and it'll be available soon."
        }
    }
}

// MARK: - Dependencies Controlling

/// `DependenciesControlling` controls:
///     1. Fetching/updating dependencies defined in `./Tuist/Dependencies.swift` by running appropriate dependencies managers (`Cocoapods`, `Carthage`, `SPM`).
///     2. Compiling fetched/updated depedencies into `.framework.`/`.xcframework.`.
///     3. Saving compiled frameworks uder `./Tuist/Dependencies/*`.
public protocol DependenciesControlling {
    /// Installes dependencies.
    /// - Parameter path: Directory whose project's dependencies will be installed.
    /// - Parameter method: Installation method.
    func install(at path: AbsolutePath, method: InstallDependenciesMethod) throws
}

// MARK: - Dependencies Controller

public final class DependenciesController: DependenciesControlling {
    private let carthageInteractor: CarthageInteracting
    private let cocoapodsInteractor: CocoapodsInteracting
    private let spmInteractor: SPMInteracting
    
    public init(carthageInteractor: CarthageInteracting = CarthageInteractor(),
                cocoapodsInteractor: CocoapodsInteracting = CocoapodsInteractor(),
                spmInteractor: SPMInteracting = SPMInteractor()) {
        self.carthageInteractor = carthageInteractor
        self.cocoapodsInteractor = cocoapodsInteractor
        self.spmInteractor = spmInteractor
    }
    
    public func install(at path: AbsolutePath, method: InstallDependenciesMethod) throws {
        logger.notice("Start installing depednencies.")
        
        // TODO: implement me!
        throw DependenciesControllerError.unimplemented
    }
}
