import Foundation

struct ProductsCommandHandler: CLICommandHandler {
    let names = ["products"]
    func execute(cli: CLI, arguments: [String], jsonOutput _: Bool) throws {
        _ = arguments
        try cli.products()
    }
}

struct DetectCommandHandler: CLICommandHandler {
    let names = ["detect", "doctor"]
    func execute(cli: CLI, arguments: [String], jsonOutput: Bool) throws {
        _ = arguments
        try cli.detect(json: jsonOutput)
    }
}

struct SkillsCommandHandler: CLICommandHandler {
    let names = ["skills"]
    func execute(cli: CLI, arguments: [String], jsonOutput _: Bool) throws {
        _ = arguments
        try cli.skills()
    }
}

struct AddCommandHandler: CLICommandHandler {
    let names = ["add"]
    func execute(cli: CLI, arguments: [String], jsonOutput _: Bool) throws {
        try cli.add(arguments: arguments)
    }
}

struct StageCommandHandler: CLICommandHandler {
    let names = ["stage"]
    func execute(cli: CLI, arguments: [String], jsonOutput _: Bool) throws {
        try cli.addFromLegacyStage(arguments: arguments)
    }
}

struct UnstageCommandHandler: CLICommandHandler {
    let names = ["unstage"]
    func execute(cli: CLI, arguments: [String], jsonOutput _: Bool) throws {
        try cli.unstage(arguments: arguments)
    }
}

struct DeployCommandHandler: CLICommandHandler {
    let names = ["deploy"]
    func execute(cli: CLI, arguments: [String], jsonOutput _: Bool) throws {
        try cli.deploy(arguments: arguments)
    }
}

struct InstallCommandHandler: CLICommandHandler {
    let names = ["install"]
    func execute(cli: CLI, arguments: [String], jsonOutput _: Bool) throws {
        try cli.deploy(arguments: arguments, legacyAlias: true)
    }
}

struct ApplyCommandHandler: CLICommandHandler {
    let names = ["apply", "setup"]
    func execute(cli: CLI, arguments: [String], jsonOutput _: Bool) throws {
        try cli.apply(arguments: arguments)
    }
}

struct UninstallCommandHandler: CLICommandHandler {
    let names = ["uninstall"]
    func execute(cli: CLI, arguments: [String], jsonOutput _: Bool) throws {
        try cli.uninstall(arguments: arguments)
    }
}

struct EnableCommandHandler: CLICommandHandler {
    let names = ["enable"]
    func execute(cli: CLI, arguments: [String], jsonOutput _: Bool) throws {
        try cli.toggle(arguments: arguments, enabled: true)
    }
}

struct DisableCommandHandler: CLICommandHandler {
    let names = ["disable"]
    func execute(cli: CLI, arguments: [String], jsonOutput _: Bool) throws {
        try cli.toggle(arguments: arguments, enabled: false)
    }
}

struct RemoveCommandHandler: CLICommandHandler {
    let names = ["remove"]
    func execute(cli: CLI, arguments: [String], jsonOutput _: Bool) throws {
        try cli.remove(arguments: arguments)
    }
}

struct StatusCommandHandler: CLICommandHandler {
    let names = ["status"]
    func execute(cli: CLI, arguments: [String], jsonOutput: Bool) throws {
        try cli.status(arguments: arguments, json: jsonOutput)
    }
}

struct HelpCommandHandler: CLICommandHandler {
    let names = ["help", "-h", "--help"]
    func execute(cli: CLI, arguments: [String], jsonOutput _: Bool) throws {
        _ = arguments
        cli.printUsage()
    }
}
