import 'dart:io';

import 'package:git/git.dart' as git;

var directories = <String>[
  'test',
  '/home/rknell/Projects/distillery_pos'
];

main() async {

  // read each directory from the list
  for (var directoryPath in directories) {

    var directory = Directory(directoryPath);
    var gitDir = await git.GitDir.fromExisting(directory.absolute.path);

    // Check if there are any changes
    var statusResult = await gitDir.runCommand(['status', '--porcelain']);
    if (statusResult.stdout.toString().isEmpty) {
      print('No changes in $directoryPath');
      continue;
    }
    
    // Check last modification time
    var result = await gitDir.runCommand(['log', '-1', '--format=%ct']);
    var lastCommitTimestamp = int.parse(result.stdout.toString().trim());
    var lastCommitDate = DateTime.fromMillisecondsSinceEpoch(lastCommitTimestamp * 1000);
    var timeSinceLastCommit = DateTime.now().difference(lastCommitDate);
    
    if (timeSinceLastCommit.inHours < 24) {
      print('Last change in $directoryPath is less than 24 hours old. Skipping backup.');
      continue;
    }

    var status = await gitDir.isWorkingTreeClean();
    if (status == true) {
      print('No uncommited changes in $directoryPath');
      await gitDir.runCommand(['push', 'origin', 'backup']);
      continue;
    }

    // Check if there are files to add
    print('Adding modified files in $directoryPath');
    await gitDir.runCommand(['add', '.']);

    // Check if backup branch exists
    var branchResult = await gitDir.runCommand(['branch', '--list', 'backup']);
    var backupBranchExists = branchResult.stdout.toString().contains('backup');
    
    if (backupBranchExists) {
      print('Switching to backup branch in $directoryPath');
      await gitDir.runCommand(['checkout', 'backup']);
    } else {
      print('Creating backup branch in $directoryPath');
      await gitDir.runCommand(['checkout', '-b', 'backup']);
    }

    // commit changes
    print('Committing changes in $directoryPath');
    await gitDir.runCommand(['commit', '-m', 'Backup ${DateTime.now().toIso8601String()}']);

    // push the new branch to remote repository
    print('Pushing changes to remote repository in $directoryPath');
    await gitDir.runCommand(['push', '--set-upstream', 'origin', 'backup']);
 
  }

}