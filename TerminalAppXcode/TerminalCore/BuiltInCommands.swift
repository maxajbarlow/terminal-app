import Foundation

// MARK: - Built-in iOS/Unix Commands

public struct BuiltInCommand {
    let name: String
    let description: String
    let usage: String
    let examples: [String]
    let category: CommandCategory
}

public enum CommandCategory: String, CaseIterable {
    case fileSystem = "File System"
    case processManagement = "Process Management"
    case networking = "Networking"
    case textProcessing = "Text Processing"
    case systemInfo = "System Information"
    case archiveCompression = "Archive & Compression"
    case permissions = "Permissions & Security"
    case search = "Search & Find"
    case development = "Development Tools"
    case shellBuiltins = "Shell Built-ins"
}

public class BuiltInCommandRegistry {
    public static let shared = BuiltInCommandRegistry()
    
    public let commands: [BuiltInCommand] = [
        // MARK: - File System Commands
        BuiltInCommand(
            name: "ls",
            description: "List directory contents",
            usage: "ls [options] [path]",
            examples: ["ls", "ls -la", "ls -lh /usr/bin"],
            category: .fileSystem
        ),
        BuiltInCommand(
            name: "cd",
            description: "Change current directory",
            usage: "cd [directory]",
            examples: ["cd /usr/local", "cd ~", "cd .."],
            category: .fileSystem
        ),
        BuiltInCommand(
            name: "pwd",
            description: "Print working directory",
            usage: "pwd",
            examples: ["pwd"],
            category: .fileSystem
        ),
        BuiltInCommand(
            name: "mkdir",
            description: "Create directories",
            usage: "mkdir [options] directory_name",
            examples: ["mkdir newdir", "mkdir -p path/to/dir"],
            category: .fileSystem
        ),
        BuiltInCommand(
            name: "rmdir",
            description: "Remove empty directories",
            usage: "rmdir directory_name",
            examples: ["rmdir empty_dir"],
            category: .fileSystem
        ),
        BuiltInCommand(
            name: "rm",
            description: "Remove files or directories",
            usage: "rm [options] file",
            examples: ["rm file.txt", "rm -rf directory", "rm -i *.tmp"],
            category: .fileSystem
        ),
        BuiltInCommand(
            name: "cp",
            description: "Copy files or directories",
            usage: "cp [options] source destination",
            examples: ["cp file1.txt file2.txt", "cp -r dir1 dir2"],
            category: .fileSystem
        ),
        BuiltInCommand(
            name: "mv",
            description: "Move or rename files and directories",
            usage: "mv [options] source destination",
            examples: ["mv oldname.txt newname.txt", "mv file.txt /path/to/dest"],
            category: .fileSystem
        ),
        BuiltInCommand(
            name: "touch",
            description: "Create empty file or update timestamps",
            usage: "touch [options] file",
            examples: ["touch newfile.txt", "touch -t 202301011200 file.txt"],
            category: .fileSystem
        ),
        BuiltInCommand(
            name: "ln",
            description: "Create links between files",
            usage: "ln [options] source target",
            examples: ["ln -s /path/to/file link_name", "ln file.txt hardlink.txt"],
            category: .fileSystem
        ),
        BuiltInCommand(
            name: "df",
            description: "Display disk space usage",
            usage: "df [options]",
            examples: ["df", "df -h", "df -H /"],
            category: .fileSystem
        ),
        BuiltInCommand(
            name: "du",
            description: "Display directory space usage",
            usage: "du [options] [path]",
            examples: ["du", "du -sh *", "du -h --max-depth=1"],
            category: .fileSystem
        ),
        
        // MARK: - Text Processing Commands
        BuiltInCommand(
            name: "cat",
            description: "Concatenate and display files",
            usage: "cat [options] file",
            examples: ["cat file.txt", "cat file1.txt file2.txt"],
            category: .textProcessing
        ),
        BuiltInCommand(
            name: "less",
            description: "View file content page by page",
            usage: "less [options] file",
            examples: ["less largefile.txt", "less +F logfile.log"],
            category: .textProcessing
        ),
        BuiltInCommand(
            name: "more",
            description: "View file content page by page (simpler than less)",
            usage: "more file",
            examples: ["more file.txt"],
            category: .textProcessing
        ),
        BuiltInCommand(
            name: "head",
            description: "Display first lines of a file",
            usage: "head [options] file",
            examples: ["head file.txt", "head -n 20 file.txt"],
            category: .textProcessing
        ),
        BuiltInCommand(
            name: "tail",
            description: "Display last lines of a file",
            usage: "tail [options] file",
            examples: ["tail file.txt", "tail -n 50 file.txt", "tail -f logfile.log"],
            category: .textProcessing
        ),
        BuiltInCommand(
            name: "echo",
            description: "Display text",
            usage: "echo [options] text",
            examples: ["echo 'Hello World'", "echo $PATH", "echo -n 'No newline'"],
            category: .textProcessing
        ),
        BuiltInCommand(
            name: "printf",
            description: "Format and print text",
            usage: "printf format [arguments]",
            examples: ["printf 'Hello %s\\n' World", "printf '%d\\n' 42"],
            category: .textProcessing
        ),
        BuiltInCommand(
            name: "grep",
            description: "Search text patterns in files",
            usage: "grep [options] pattern file",
            examples: ["grep 'error' logfile.txt", "grep -r 'TODO' .", "grep -i 'pattern' file.txt"],
            category: .textProcessing
        ),
        BuiltInCommand(
            name: "sed",
            description: "Stream editor for text manipulation",
            usage: "sed [options] 'command' file",
            examples: ["sed 's/old/new/g' file.txt", "sed -n '1,10p' file.txt"],
            category: .textProcessing
        ),
        BuiltInCommand(
            name: "awk",
            description: "Pattern scanning and processing language",
            usage: "awk 'pattern { action }' file",
            examples: ["awk '{print $1}' file.txt", "awk -F',' '{print $2}' data.csv"],
            category: .textProcessing
        ),
        BuiltInCommand(
            name: "sort",
            description: "Sort lines in text files",
            usage: "sort [options] file",
            examples: ["sort file.txt", "sort -n numbers.txt", "sort -r file.txt"],
            category: .textProcessing
        ),
        BuiltInCommand(
            name: "uniq",
            description: "Report or filter unique lines",
            usage: "uniq [options] file",
            examples: ["uniq file.txt", "uniq -c file.txt", "sort file.txt | uniq"],
            category: .textProcessing
        ),
        BuiltInCommand(
            name: "cut",
            description: "Extract columns from files",
            usage: "cut [options] file",
            examples: ["cut -f 1,3 -d ',' data.csv", "cut -c 1-10 file.txt"],
            category: .textProcessing
        ),
        BuiltInCommand(
            name: "paste",
            description: "Merge lines of files",
            usage: "paste [options] file1 file2",
            examples: ["paste file1.txt file2.txt", "paste -d ',' file1 file2"],
            category: .textProcessing
        ),
        BuiltInCommand(
            name: "tr",
            description: "Translate or delete characters",
            usage: "tr [options] set1 set2",
            examples: ["tr 'a-z' 'A-Z' < file.txt", "tr -d '\\r' < windows.txt"],
            category: .textProcessing
        ),
        BuiltInCommand(
            name: "wc",
            description: "Word, line, character, and byte count",
            usage: "wc [options] file",
            examples: ["wc file.txt", "wc -l file.txt", "wc -w document.txt"],
            category: .textProcessing
        ),
        
        // MARK: - Process Management Commands
        BuiltInCommand(
            name: "ps",
            description: "Display process status",
            usage: "ps [options]",
            examples: ["ps", "ps aux", "ps -ef"],
            category: .processManagement
        ),
        BuiltInCommand(
            name: "top",
            description: "Display running processes",
            usage: "top [options]",
            examples: ["top", "top -u username"],
            category: .processManagement
        ),
        BuiltInCommand(
            name: "kill",
            description: "Terminate processes",
            usage: "kill [signal] PID",
            examples: ["kill 1234", "kill -9 1234", "kill -TERM 1234"],
            category: .processManagement
        ),
        BuiltInCommand(
            name: "killall",
            description: "Kill processes by name",
            usage: "killall [options] process_name",
            examples: ["killall Safari", "killall -9 hung_process"],
            category: .processManagement
        ),
        BuiltInCommand(
            name: "jobs",
            description: "List active jobs",
            usage: "jobs [options]",
            examples: ["jobs", "jobs -l"],
            category: .processManagement
        ),
        BuiltInCommand(
            name: "bg",
            description: "Resume jobs in background",
            usage: "bg [job_spec]",
            examples: ["bg", "bg %1"],
            category: .processManagement
        ),
        BuiltInCommand(
            name: "fg",
            description: "Bring job to foreground",
            usage: "fg [job_spec]",
            examples: ["fg", "fg %1"],
            category: .processManagement
        ),
        BuiltInCommand(
            name: "nohup",
            description: "Run command immune to hangups",
            usage: "nohup command [arguments]",
            examples: ["nohup ./long_script.sh &", "nohup python3 server.py > output.log &"],
            category: .processManagement
        ),
        
        // MARK: - Networking Commands
        BuiltInCommand(
            name: "ping",
            description: "Test network connectivity",
            usage: "ping [options] host",
            examples: ["ping google.com", "ping -c 4 192.168.1.1"],
            category: .networking
        ),
        BuiltInCommand(
            name: "curl",
            description: "Transfer data from/to servers",
            usage: "curl [options] URL",
            examples: ["curl https://example.com", "curl -o file.txt https://example.com/file", "curl -X POST -d 'data' https://api.example.com"],
            category: .networking
        ),
        BuiltInCommand(
            name: "wget",
            description: "Download files from the web",
            usage: "wget [options] URL",
            examples: ["wget https://example.com/file.zip", "wget -r https://example.com"],
            category: .networking
        ),
        BuiltInCommand(
            name: "netstat",
            description: "Display network connections",
            usage: "netstat [options]",
            examples: ["netstat", "netstat -an", "netstat -tulpn"],
            category: .networking
        ),
        BuiltInCommand(
            name: "ifconfig",
            description: "Configure network interface",
            usage: "ifconfig [interface] [options]",
            examples: ["ifconfig", "ifconfig en0"],
            category: .networking
        ),
        BuiltInCommand(
            name: "ssh",
            description: "Secure Shell client",
            usage: "ssh [options] user@host",
            examples: ["ssh user@server.com", "ssh -p 2222 user@host", "ssh -i key.pem user@server"],
            category: .networking
        ),
        BuiltInCommand(
            name: "scp",
            description: "Secure copy files over network",
            usage: "scp [options] source destination",
            examples: ["scp file.txt user@server:/path/", "scp -r folder/ user@server:/backup/"],
            category: .networking
        ),
        BuiltInCommand(
            name: "nc",
            description: "Netcat - networking utility",
            usage: "nc [options] host port",
            examples: ["nc -l 8080", "nc server.com 80", "echo 'test' | nc server.com 9999"],
            category: .networking
        ),
        
        // MARK: - System Information Commands
        BuiltInCommand(
            name: "uname",
            description: "Display system information",
            usage: "uname [options]",
            examples: ["uname", "uname -a", "uname -m"],
            category: .systemInfo
        ),
        BuiltInCommand(
            name: "whoami",
            description: "Display current username",
            usage: "whoami",
            examples: ["whoami"],
            category: .systemInfo
        ),
        BuiltInCommand(
            name: "hostname",
            description: "Display or set system hostname",
            usage: "hostname [options]",
            examples: ["hostname", "hostname -f"],
            category: .systemInfo
        ),
        BuiltInCommand(
            name: "date",
            description: "Display or set system date and time",
            usage: "date [options]",
            examples: ["date", "date '+%Y-%m-%d'", "date -u"],
            category: .systemInfo
        ),
        BuiltInCommand(
            name: "uptime",
            description: "Show system uptime",
            usage: "uptime",
            examples: ["uptime"],
            category: .systemInfo
        ),
        BuiltInCommand(
            name: "which",
            description: "Locate a command",
            usage: "which command",
            examples: ["which python", "which ls"],
            category: .systemInfo
        ),
        BuiltInCommand(
            name: "whereis",
            description: "Locate binary, source, and manual pages",
            usage: "whereis command",
            examples: ["whereis python", "whereis ls"],
            category: .systemInfo
        ),
        BuiltInCommand(
            name: "env",
            description: "Display environment variables",
            usage: "env [options]",
            examples: ["env", "env | grep PATH"],
            category: .systemInfo
        ),
        BuiltInCommand(
            name: "printenv",
            description: "Print environment variables",
            usage: "printenv [variable]",
            examples: ["printenv", "printenv PATH", "printenv HOME"],
            category: .systemInfo
        ),
        
        // MARK: - Archive & Compression Commands
        BuiltInCommand(
            name: "tar",
            description: "Archive files",
            usage: "tar [options] archive_name files",
            examples: ["tar -czf archive.tar.gz folder/", "tar -xzf archive.tar.gz", "tar -tvf archive.tar"],
            category: .archiveCompression
        ),
        BuiltInCommand(
            name: "gzip",
            description: "Compress files",
            usage: "gzip [options] file",
            examples: ["gzip file.txt", "gzip -d file.txt.gz", "gzip -9 largefile.txt"],
            category: .archiveCompression
        ),
        BuiltInCommand(
            name: "gunzip",
            description: "Decompress gzip files",
            usage: "gunzip file.gz",
            examples: ["gunzip file.txt.gz"],
            category: .archiveCompression
        ),
        BuiltInCommand(
            name: "zip",
            description: "Create zip archives",
            usage: "zip [options] archive.zip files",
            examples: ["zip archive.zip file1 file2", "zip -r archive.zip folder/"],
            category: .archiveCompression
        ),
        BuiltInCommand(
            name: "unzip",
            description: "Extract zip archives",
            usage: "unzip [options] archive.zip",
            examples: ["unzip archive.zip", "unzip -l archive.zip", "unzip archive.zip -d destination/"],
            category: .archiveCompression
        ),
        
        // MARK: - Permissions & Security Commands
        BuiltInCommand(
            name: "chmod",
            description: "Change file permissions",
            usage: "chmod [options] mode file",
            examples: ["chmod 755 script.sh", "chmod +x file.sh", "chmod u+w,g-w file.txt"],
            category: .permissions
        ),
        BuiltInCommand(
            name: "chown",
            description: "Change file ownership",
            usage: "chown [options] owner:group file",
            examples: ["chown user:group file.txt", "chown -R user folder/"],
            category: .permissions
        ),
        BuiltInCommand(
            name: "sudo",
            description: "Execute command as superuser",
            usage: "sudo [options] command",
            examples: ["sudo apt-get update", "sudo -u user command"],
            category: .permissions
        ),
        BuiltInCommand(
            name: "su",
            description: "Switch user",
            usage: "su [options] [username]",
            examples: ["su", "su - username"],
            category: .permissions
        ),
        BuiltInCommand(
            name: "passwd",
            description: "Change user password",
            usage: "passwd [username]",
            examples: ["passwd", "passwd username"],
            category: .permissions
        ),
        
        // MARK: - Search & Find Commands
        BuiltInCommand(
            name: "find",
            description: "Search for files and directories",
            usage: "find [path] [options] [expression]",
            examples: ["find . -name '*.txt'", "find / -type d -name 'config'", "find . -mtime -7"],
            category: .search
        ),
        BuiltInCommand(
            name: "locate",
            description: "Find files by name (uses database)",
            usage: "locate [options] pattern",
            examples: ["locate filename", "locate -i pattern"],
            category: .search
        ),
        BuiltInCommand(
            name: "updatedb",
            description: "Update locate database",
            usage: "updatedb [options]",
            examples: ["sudo updatedb"],
            category: .search
        ),
        
        // MARK: - Development Tools
        BuiltInCommand(
            name: "git",
            description: "Version control system",
            usage: "git [command] [options]",
            examples: ["git init", "git clone https://github.com/user/repo.git", "git add .", "git commit -m 'message'", "git push"],
            category: .development
        ),
        BuiltInCommand(
            name: "make",
            description: "Build automation tool",
            usage: "make [options] [target]",
            examples: ["make", "make clean", "make install"],
            category: .development
        ),
        BuiltInCommand(
            name: "gcc",
            description: "GNU C compiler",
            usage: "gcc [options] source.c",
            examples: ["gcc program.c -o program", "gcc -Wall -g program.c"],
            category: .development
        ),
        BuiltInCommand(
            name: "python",
            description: "Python interpreter",
            usage: "python [options] [script]",
            examples: ["python", "python script.py", "python -m venv env"],
            category: .development
        ),
        BuiltInCommand(
            name: "python3",
            description: "Python 3 interpreter",
            usage: "python3 [options] [script]",
            examples: ["python3", "python3 script.py", "python3 -m pip install package"],
            category: .development
        ),
        BuiltInCommand(
            name: "node",
            description: "Node.js JavaScript runtime",
            usage: "node [options] [script]",
            examples: ["node", "node app.js", "node -v"],
            category: .development
        ),
        BuiltInCommand(
            name: "npm",
            description: "Node package manager",
            usage: "npm [command] [options]",
            examples: ["npm install", "npm start", "npm run build"],
            category: .development
        ),
        BuiltInCommand(
            name: "vim",
            description: "Vi IMproved text editor",
            usage: "vim [options] file",
            examples: ["vim file.txt", "vim +10 file.txt"],
            category: .development
        ),
        BuiltInCommand(
            name: "nano",
            description: "Simple text editor",
            usage: "nano [options] file",
            examples: ["nano file.txt", "nano -w file.txt"],
            category: .development
        ),
        
        // MARK: - Shell Built-ins
        BuiltInCommand(
            name: "alias",
            description: "Create command aliases",
            usage: "alias [name='command']",
            examples: ["alias", "alias ll='ls -la'", "alias gs='git status'"],
            category: .shellBuiltins
        ),
        BuiltInCommand(
            name: "unalias",
            description: "Remove aliases",
            usage: "unalias name",
            examples: ["unalias ll", "unalias -a"],
            category: .shellBuiltins
        ),
        BuiltInCommand(
            name: "export",
            description: "Set environment variables",
            usage: "export VARIABLE=value",
            examples: ["export PATH=$PATH:/usr/local/bin", "export EDITOR=vim"],
            category: .shellBuiltins
        ),
        BuiltInCommand(
            name: "source",
            description: "Execute commands from file in current shell",
            usage: "source file",
            examples: ["source ~/.bashrc", "source .env"],
            category: .shellBuiltins
        ),
        BuiltInCommand(
            name: "history",
            description: "Display command history",
            usage: "history [options]",
            examples: ["history", "history 20", "history -c"],
            category: .shellBuiltins
        ),
        BuiltInCommand(
            name: "clear",
            description: "Clear terminal screen",
            usage: "clear",
            examples: ["clear"],
            category: .shellBuiltins
        ),
        BuiltInCommand(
            name: "exit",
            description: "Exit the shell",
            usage: "exit [code]",
            examples: ["exit", "exit 0", "exit 1"],
            category: .shellBuiltins
        ),
        BuiltInCommand(
            name: "type",
            description: "Display command type",
            usage: "type command",
            examples: ["type ls", "type cd"],
            category: .shellBuiltins
        ),
        BuiltInCommand(
            name: "read",
            description: "Read input from user",
            usage: "read [options] variable",
            examples: ["read name", "read -p 'Enter name: ' name"],
            category: .shellBuiltins
        ),
        BuiltInCommand(
            name: "test",
            description: "Evaluate conditional expressions",
            usage: "test expression",
            examples: ["test -f file.txt", "test $var -eq 5"],
            category: .shellBuiltins
        )
    ]
    
    private init() {}
    
    // MARK: - Helper Methods
    
    public func searchCommands(query: String) -> [BuiltInCommand] {
        let lowercasedQuery = query.lowercased()
        return commands.filter { command in
            command.name.lowercased().contains(lowercasedQuery) ||
            command.description.lowercased().contains(lowercasedQuery)
        }
    }
    
    public func commandsByCategory(_ category: CommandCategory) -> [BuiltInCommand] {
        return commands.filter { $0.category == category }
    }
    
    public func getCommand(named name: String) -> BuiltInCommand? {
        return commands.first { $0.name == name }
    }
    
    public func getAllCommandNames() -> [String] {
        return commands.map { $0.name }.sorted()
    }
    
    public func generateHelp(for commandName: String) -> String? {
        guard let command = getCommand(named: commandName) else { return nil }
        
        var help = """
        \(command.name) - \(command.description)
        
        Usage: \(command.usage)
        
        Examples:
        """
        
        for example in command.examples {
            help += "\n  $ \(example)"
        }
        
        return help
    }
    
    public func generateQuickReference() -> String {
        var reference = "iOS/Unix Command Quick Reference\n"
        reference += "=" .repeated(40) + "\n\n"
        
        for category in CommandCategory.allCases {
            let categoryCommands = commandsByCategory(category)
            if !categoryCommands.isEmpty {
                reference += "\(category.rawValue):\n"
                for command in categoryCommands {
                    reference += "  \(command.name.padded(to: 15)) - \(command.description)\n"
                }
                reference += "\n"
            }
        }
        
        return reference
    }
}

// MARK: - String Extensions

extension String {
    func repeated(_ count: Int) -> String {
        return String(repeating: self, count: count)
    }
    
    func padded(to length: Int) -> String {
        if self.count >= length {
            return self
        }
        return self + String(repeating: " ", count: length - self.count)
    }
}

// MARK: - Command Completion Support

public class CommandCompleter {
    private let registry = BuiltInCommandRegistry.shared
    
    public func complete(partial: String) -> [String] {
        let commands = registry.getAllCommandNames()
        
        if partial.isEmpty {
            return commands
        }
        
        return commands.filter { $0.hasPrefix(partial) }
    }
    
    public func suggestNext(after command: String, currentArgs: [String]) -> [String] {
        // This could be expanded to provide context-aware suggestions
        // For example, after "cd", suggest directories
        // After "git", suggest git subcommands, etc.
        
        switch command {
        case "cd":
            return ["~", "..", "/", "/usr", "/etc", "/var"]
        case "git":
            return ["init", "clone", "add", "commit", "push", "pull", "status", "log", "branch", "checkout", "merge"]
        case "ls":
            return ["-l", "-a", "-la", "-lh", "-R"]
        case "grep":
            return ["-i", "-r", "-n", "-v", "-c"]
        case "find":
            return ["-name", "-type", "-size", "-mtime", "-exec"]
        case "chmod":
            return ["755", "644", "777", "+x", "-x", "u+w", "g-w"]
        default:
            return []
        }
    }
}