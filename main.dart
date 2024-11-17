import 'dart:io';

import 'package:git/git.dart' as git;

var directories = <String>[
  '/home/rknell/Projects/'
];

void main(List<String> args) {
  for (var directoryPath in directories) {
    var directory = Directory(directoryPath);
    processDirectory(directory);
  }
}

Future<void> processDirectory(Directory directory) async {
  // Check if current directory is a git repository
  // list all subdirectories and process them
  var subEntities = await directory.list().toList();
  for (var subEntity in subEntities) {
    if (subEntity is Directory) {
      if (subEntity.path.endsWith('.git')) {
        await processGitRepository(directory);
      } else {
        await processDirectory(subEntity);
      }
    }
  }
}


Future<void> processGitRepository(Directory directory) async {
  
    var gitDir = await git.GitDir.fromExisting(directory.absolute.path);

    // Check if there are any changes
    var statusResult = await gitDir.runCommand(['status', '--porcelain']);
    if (statusResult.stdout.toString().isEmpty) {
      print('No changes in ${directory.path}');
      return;
    }
    
    // Check last modification time
    var result = await gitDir.runCommand(['log', '-1', '--format=%ct']);
    var lastCommitTimestamp = int.parse(result.stdout.toString().trim());
    var lastCommitDate = DateTime.fromMillisecondsSinceEpoch(lastCommitTimestamp * 1000);
    var timeSinceLastCommit = DateTime.now().difference(lastCommitDate);
    
    if (timeSinceLastCommit.inHours < 0) {
      print('Last change in ${directory.path} is less than 24 hours old. Skipping backup.');
      return;
    }

    var status = await gitDir.isWorkingTreeClean();
    if (status == true) {
      print('No uncommited changes in ${directory.path}');
      await gitDir.runCommand(['push', 'origin', 'backup']);
      return;
    }

    // Check if there are files to add
    print('Adding modified files in ${directory.path}');
    await gitDir.runCommand(['add', '.']);

    // Check if backup branch exists
    var branchResult = await gitDir.runCommand(['branch', '--list', 'backup']);
    var backupBranchExists = branchResult.stdout.toString().contains('backup');
    
    if (backupBranchExists) {
      print('Switching to backup branch in ${directory.path}');
      await gitDir.runCommand(['checkout', 'backup']);
    } else {
      print('Creating backup branch in ${directory.path}');
      await gitDir.runCommand(['checkout', '-b', 'backup']);
    }

    // commit changes
    print('Committing changes in ${directory.path}');
    await gitDir.runCommand(['commit', '-m', 'Backup ${DateTime.now().toIso8601String()}']);

    try {
      // push the new branch to remote repository
      print('Pushing changes to remote repository in ${directory.path}');
      await gitDir.runCommand(['push', '--set-upstream', 'origin', 'backup']);
    } catch(e) {
    print('Error pushing changes to remote repository in ${directory.path}: $e');
  }
}