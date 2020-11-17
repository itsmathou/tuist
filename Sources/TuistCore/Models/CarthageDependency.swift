import Foundation

/// CarthageDependency contains the description of a dependency to be fetched with Carthage.
public struct CarthageDependency: Equatable {
    /// Name of the dependency
    public let name: String

    /// Type of requirement for the given dependency
    public let requirement: Requirement
    
    /// Initializes the carthage dependency with its attributes.
    ///
    /// - Parameters:
    ///   - name: Name of the dependency
    ///   - requirement: Type of requirement for the given dependency
    public init(
        name: String,
        requirement: Requirement
    ) {
        self.name = name
        self.requirement = requirement
    }
}
