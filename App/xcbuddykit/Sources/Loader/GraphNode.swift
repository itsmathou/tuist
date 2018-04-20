import Basic
import Foundation

/// Dependency graph node.
class GraphNode: Equatable {
    /// Node path.
    let path: AbsolutePath

    /// Initializes the node with its path.
    ///
    /// - Parameter path: path to the node.
    init(path: AbsolutePath) {
        self.path = path
    }

    static func == (lhs: GraphNode, rhs: GraphNode) -> Bool {
        return lhs.path == rhs.path
    }
}

/// Graph node that represents a project target (to be generaterd).
class TargetNode: GraphNode {
    /// Project that contains the target definition.
    let project: Project

    /// Target definition.
    let target: Target

    /// Node dependencies.
    var dependencies: [GraphNode]

    /// Initializes the target node with its attribute.
    ///
    /// - Parameters:
    ///   - project: project that contains the target definition.
    ///   - target: target description.
    ///   - dependencies: node dependencies.
    init(project: Project,
         target: Target,
         dependencies: [GraphNode]) {
        self.project = project
        self.target = target
        self.dependencies = dependencies
        super.init(path: project.path)
    }

    static func read(name: String, path: AbsolutePath, context: GraphLoaderContexting) throws -> TargetNode {
        if let targetNode = context.cache.node(path) as? TargetNode { return targetNode }
        let project = try Project.read(path: path, context: context)
        guard let target = project.targets.first(where: { $0.name == name }) else {
            throw GraphLoadingError.targetNotFound(name, path)
        }
        let dependencyMapper = TargetNode.readDependency(projectPath: path, context: context)
        let dependencies: [GraphNode] = try target.dependencies.compactMap(dependencyMapper)
        let targetNode = TargetNode(project: project, target: target, dependencies: dependencies)
        context.cache.add(node: targetNode)
        return targetNode
    }

    static func readDependency(projectPath: AbsolutePath, context: GraphLoaderContexting) -> (_ dictionary: JSON) throws -> GraphNode {
        return { json in
            let type: String = try json.get("type")
            if type == "target" {
                let name: String = try json.get("name")
                return try TargetNode.read(name: name, path: projectPath, context: context)
            } else if type == "project" {
                let name: String = try json.get("name")
                let projectRelativePath: RelativePath = try RelativePath(json.get("path"))
                let projectPath = projectPath.appending(projectRelativePath)
                return try TargetNode.read(name: name, path: projectPath, context: context)
            } else if type == "framework" {
                let frameworkPath: RelativePath = try RelativePath(json.get("path"))
                return try FrameworkNode.read(json: json,
                                              projectPath: projectPath,
                                              path: frameworkPath,
                                              context: context)
            } else if type == "library" {
                let libraryPath: RelativePath = try RelativePath(json.get("path"))
                return try LibraryNode.read(json: json,
                                            projectPath: projectPath,
                                            path: libraryPath,
                                            context: context)
            } else {
                fatalError("Invalid dependency type: \(type)")
            }
        }
    }
}

/// Graph node that represents a framework.
class FrameworkNode: GraphNode {
    static func read(json _: JSON,
                     projectPath: AbsolutePath,
                     path: RelativePath,
                     context: GraphLoaderContexting) throws -> FrameworkNode {
        let absolutePath = projectPath.appending(path)
        if !context.fileHandler.exists(absolutePath) {
            throw GraphLoadingError.missingFile(absolutePath)
        }
        if let frameworkNode = context.cache.node(absolutePath) as? FrameworkNode { return frameworkNode }
        let framewokNode = FrameworkNode(path: absolutePath)
        context.cache.add(node: framewokNode)
        return framewokNode
    }
}

class LibraryNode: GraphNode {
    let publicHeader: AbsolutePath
    let swiftModuleMap: AbsolutePath?

    init(path: AbsolutePath,
         publicHeader: AbsolutePath,
         swiftModuleMap: AbsolutePath? = nil) {
        self.publicHeader = publicHeader
        self.swiftModuleMap = swiftModuleMap
        super.init(path: path)
    }

    static func read(json: JSON,
                     projectPath: AbsolutePath,
                     path: RelativePath,
                     context: GraphLoaderContexting) throws -> LibraryNode {
        let libraryAbsolutePath = projectPath.appending(path)
        if !context.fileHandler.exists(libraryAbsolutePath) {
            throw GraphLoadingError.missingFile(libraryAbsolutePath)
        }
        if let libraryNode = context.cache.node(libraryAbsolutePath) as? LibraryNode { return libraryNode }
        let publicHeadersRelativePath: RelativePath = try RelativePath(json.get("public_headers"))
        let publicHeadersPath = projectPath.appending(publicHeadersRelativePath)
        if !context.fileHandler.exists(publicHeadersPath) {
            throw GraphLoadingError.missingFile(publicHeadersPath)
        }
        var swiftModuleMapPath: AbsolutePath?
        if let swiftModuleMapRelativePathString: String = json.get("swift_module_map") {
            let swiftModuleMapRelativePath = RelativePath(swiftModuleMapRelativePathString)
            swiftModuleMapPath = projectPath.appending(swiftModuleMapRelativePath)
            if !context.fileHandler.exists(swiftModuleMapPath!) {
                throw GraphLoadingError.missingFile(swiftModuleMapPath!)
            }
        }
        let libraryNode = LibraryNode(path: libraryAbsolutePath,
                                      publicHeader: publicHeadersPath,
                                      swiftModuleMap: swiftModuleMapPath)
        context.cache.add(node: libraryNode)
        return libraryNode
    }
}
