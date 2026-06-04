# -*- coding: utf-8 -*-
# Ansible callback plugin: when a run stops on a failed task, print a friendly,
# copy-paste hint explaining how to resume from that exact task (and the
# always-safe option of just re-running the whole, idempotent play).
#
# Enabled via ansible.cfg:
#   [defaults]
#   callback_plugins = ./callback_plugins
#   callbacks_enabled = resume_hint
from __future__ import annotations

import os
import shlex
import sys

from ansible.plugins.callback import CallbackBase

DOCUMENTATION = '''
    name: resume_hint
    type: aggregate
    short_description: Friendly "how to resume" hint when a play fails
    version_added: "1.0"
    description:
      - When a task fails and the run stops, prints the failed task name and a
        ready-to-paste ansible-playbook command that resumes from that task via
        C(--start-at-task), plus the always-safe option of re-running the whole
        idempotent play.
    requirements:
      - Enable with 'callbacks_enabled = resume_hint' in ansible.cfg
'''


class CallbackModule(CallbackBase):
    """Print a resume hint at the end of a failed run."""

    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'aggregate'
    CALLBACK_NAME = 'resume_hint'
    CALLBACK_NEEDS_ENABLED = True

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._failed_display_name = None  # role-prefixed, for showing the user
        self._failed_resume_name = None   # bare name, for --start-at-task

    def v2_runner_on_failed(self, result, ignore_errors=False):
        # A task with ignore_errors does not stop the run, so it is not a
        # resume point.
        if ignore_errors:
            return
        task = result._task
        # Keep the most recent real failure: once a task fails fatally, no
        # further tasks run on that host, so the last one we see is where the
        # run actually stopped (and earlier rescued failures get overwritten).
        display_name = task.get_name().strip()
        bare_name = (task.name or '').strip()
        self._failed_display_name = display_name or bare_name or task.action
        self._failed_resume_name = bare_name or display_name or task.action

    def v2_playbook_on_stats(self, stats):
        # Only nudge if the run actually ended in failure. If a failed task was
        # rescued and the play went on to succeed, there is nothing to resume.
        ended_in_failure = any(
            stats.failures.get(host, 0) or stats.dark.get(host, 0)
            for host in stats.processed
        )
        if not ended_in_failure or not self._failed_resume_name:
            return

        argv = list(sys.argv)
        if argv:
            argv[0] = os.path.basename(argv[0]) or 'ansible-playbook'
        else:
            argv = ['ansible-playbook']
        base_cmd = ' '.join(shlex.quote(arg) for arg in argv)
        resume_cmd = base_cmd + ' --start-at-task=' + shlex.quote(self._failed_resume_name)

        line = '─' * 70
        cyan, green, yellow = 'cyan', 'green', 'yellow'
        show = self._display.display

        show('')
        show(line, color=cyan)
        show('💡  Looks like the run stopped at this task:', color=cyan)
        show('')
        show('        %s' % self._failed_display_name, color=yellow)
        show('')
        show("Good news — once you've fixed what caused it, you usually don't have")
        show("to start over. From the project's  ansible/  directory you can pick")
        show('up right where it left off:')
        show('')
        show('    ' + resume_cmd, color=green)
        show('')
        show('🙏  One gentle caveat: resuming this way only works if the task above', color=yellow)
        show("    doesn't depend on something an earlier task set up (a registered", color=yellow)
        show('    variable, a gathered fact, a set_fact, and so on). If you get a', color=yellow)
        show('    surprising "undefined variable" error after resuming, no worries', color=yellow)
        show('    — just re-run the whole step. It is idempotent, so everything', color=yellow)
        show('    that already succeeded is simply skipped:', color=yellow)
        show('')
        show('    ' + base_cmd, color=green)
        show(line, color=cyan)
        show('')
