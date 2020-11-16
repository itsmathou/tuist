import Foundation
import TSCBasic
import TuistSupport

public class ValueGraphTraverser: GraphTraversing {
    
    public var name: String { graph.name }
    public var hasPackages: Bool { !graph.packages.flatMap(\.value).isEmpty }
    public var path: AbsolutePath { graph.path }
    public var workspace: Workspace { graph.workspace }
    public var projects: [AbsolutePath: Project] { graph.projects }
    
    private let graph: ValueGraph

    public required init(graph: ValueGraph) {
        self.graph = graph
    }

    public func target(path: AbsolutePath, name: String) -> ValueGraphTarget? {
        guard let project = graph.projects[path], let target = graph.targets[path]?[name] else { return nil }
        return ValueGraphTarget.init(path: path, target: target, project: project)
    }

    public func targets(at path: AbsolutePath) -> Set<ValueGraphTarget> {
        guard let project = graph.projects[path] else { return Set() }
        guard let targets = graph.targets[path] else { return [] }
        return Set(targets.values.map({ ValueGraphTarget(path: path, target: $0, project: project) }))
    }

    public func directTargetDependencies(path: AbsolutePath, name: String) -> Set<ValueGraphTarget> {
        guard let dependencies = graph.dependencies[.target(name: name, path: path)] else { return [] }
        guard let project = graph.projects[path] else { return Set() }
        
        return Set(dependencies.flatMap { (dependency) -> [ValueGraphTarget] in
            guard case let ValueGraphDependency.target(dependencyName, dependencyPath) = dependency else { return [] }
            guard let projectDependencies = graph.targets[dependencyPath], let dependencyTarget = projectDependencies[dependencyName] else { return []
            }
            return [ValueGraphTarget.init(path: path, target: dependencyTarget, project: project)]
        })
    }

    public func resourceBundleDependencies(path: AbsolutePath, name: String) -> Set<ValueGraphTarget> {
        guard let project = graph.projects[path] else { return Set() }
        guard let target = graph.targets[path]?[name] else { return [] }
        guard target.supportsResources else { return [] }

        let canHostResources: (ValueGraphDependency) -> Bool = {
            self.target(from: $0)?.supportsResources == true
        }

        let isBundle: (ValueGraphDependency) -> Bool = {
            self.target(from: $0)?.product == .bundle
        }

        let bundles = filterDependencies(from: .target(name: name, path: path),
                                         test: isBundle,
                                         skip: canHostResources)
        let bundleTargets = bundles.compactMap(target(from:)).map({ ValueGraphTarget.init(path: path, target: $0, project: project) })

        return Set(bundleTargets)
    }

    public func testTargetsDependingOn(path: AbsolutePath, name: String) -> Set<ValueGraphTarget> {
        guard let project = graph.projects[path] else { return Set() }

        return Set(graph.targets[path]?.values
            .filter { $0.product.testsBundle }
            .filter { graph.dependencies[.target(name: $0.name, path: path)]?.contains(.target(name: name, path: path)) == true }
            .map({ ValueGraphTarget(path: path, target: $0, project: project) }) ?? [])
    }

    public func target(from dependency: ValueGraphDependency) -> Target? {
        guard case let ValueGraphDependency.target(name, path) = dependency else {
            return nil
        }
        return graph.targets[path]?[name]
    }

    public func appExtensionDependencies(path: AbsolutePath, name: String) -> Set<ValueGraphTarget> {
        let validProducts: [Product] = [
            .appExtension, .stickerPackExtension, .watch2Extension, .messagesExtension,
        ]
        return Set(directTargetDependencies(path: path, name: name)
                    .filter { validProducts.contains($0.target.product) })
    }

    public func appClipsDependency(path: AbsolutePath, name: String) -> ValueGraphTarget? {
        directTargetDependencies(path: path, name: name)
            .first { $0.target.product == .appClip }
    }

    public func directStaticDependencies(path: AbsolutePath, name: String) -> Set<GraphDependencyReference> {
        Set(graph.dependencies[.target(name: name, path: path)]?
            .compactMap { (dependency: ValueGraphDependency) -> (path: AbsolutePath, name: String)? in
                guard case let ValueGraphDependency.target(name, path) = dependency else {
                    return nil
                }
                return (path, name)
            }
            .compactMap { graph.targets[$0.path]?[$0.name] }
            .filter { $0.product.isStatic }
            .map { .product(target: $0.name, productName: $0.productNameWithExtension) } ?? [])
    }

    /// It traverses the depdency graph and returns all the dependencies.
    /// - Parameter path: Path to the project from where traverse the dependency tree.
    public func allDependencies(path: AbsolutePath) -> Set<ValueGraphDependency> {
        guard let targets = graph.targets[path]?.values else { return Set() }

        var references = Set<ValueGraphDependency>()

        targets.forEach { target in
            let dependency = ValueGraphDependency.target(name: target.name, path: path)
            references.formUnion(filterDependencies(from: dependency))
        }

        return references
    }
    
    public func embeddableFrameworks(path: AbsolutePath, name: String) throws -> Set<GraphDependencyReference> {
        return Set()
    }

    public func linkableDependencies(path: AbsolutePath, name: String) throws -> Set<GraphDependencyReference> {
        return Set()
    }

    public func copyProductDependencies(path: AbsolutePath, name: String) -> Set<GraphDependencyReference> {
        return Set()
    }

    public func librariesPublicHeadersFolders(path: AbsolutePath, name: String) -> Set<AbsolutePath> {
        return Set()
    }

    public func librariesSearchPaths(path: AbsolutePath, name: String) -> Set<AbsolutePath> {
        return Set()
    }
    
    public func librariesSwiftIncludePaths(path: AbsolutePath, name: String) -> Set<AbsolutePath> {
        return Set()
    }
    
    public func runPathSearchPaths(path: AbsolutePath, name: String) -> Set<AbsolutePath> {
        return Set()
    }
    
    // MARK: - Fileprivate
    
    /// The method collects the dependencies that are selected by the provided test closure.
    /// The skip closure allows skipping the traversing of a specific dependendency branch.
    /// - Parameters:
    ///   - from: Dependency from which the traverse is done.
    ///   - test: If the closure returns true, the dependency is included.
    ///   - skip: If the closure returns false, the traversing logic doesn't traverse the dependencies from that dependency.
    func filterDependencies(from rootDependency: ValueGraphDependency,
                            test: (ValueGraphDependency) -> Bool = { _ in true },
                            skip: (ValueGraphDependency) -> Bool = { _ in false }) -> Set<ValueGraphDependency>
    {
        var stack = Stack<ValueGraphDependency>()
        
        stack.push(rootDependency)
        
        var visited: Set<ValueGraphDependency> = .init()
        var references = Set<ValueGraphDependency>()
        
        while !stack.isEmpty {
            guard let node = stack.pop() else {
                continue
            }
            
            if visited.contains(node) {
                continue
            }
            
            visited.insert(node)
            
            if node != rootDependency, test(node) {
                references.insert(node)
            }
            
            if node != rootDependency, skip(node) {
                continue
            }
            
            graph.dependencies[node]?.forEach { nodeDependency in
                if !visited.contains(nodeDependency) {
                    stack.push(nodeDependency)
                }
            }
        }
        
        return references
    }
    
}
