if !has('python')
  finish
endif

python << endpython

import vim

def vimux_paster(unintend=True):
    """
        Pastes visually-selected blocks of code into your VimuxRunner.
    """

    # `cpaste` is a `%magic`al ipython feature that allows to paste code blocks
    # into ipython neatly. It works by prepending the code block with a special
    # `%cpaste` instruction, so it breaks other python interpreters.
    # Although ipython is very widely used for interactive debugging, and this
    # feature is superb, I am conservative and will keep it off by default.
    # CAVEAT: cpaste needs to be turned off to be able to paste python
    # code to a regular python interpreter such as cpython or pypy, only
    # enable it for use with ipython!
    use_cpaste = vim.vars.get('vimux_paster_use_cpaste_for_python')
    if use_cpaste is None:
        use_cpaste = False
    else:
        use_cpaste = bool(use_cpaste)

    # `lines` are full lines from buffer, even if only part of the line
    # was actually visually selected.
    r = vim.current.range
    lines = vim.current.buffer[r.start:r.end+1]
    filetype = vim.current.buffer.options['filetype']

    # CAVEAT: there's no way to get rectangular block visual selection
    # coordinates in python-vim, so I can't handle that special case and
    # instead whole lines would be used, and only first and last line will
    # be cropped according to the actual selection region.

    # get actual visual selection marker positions; [0] is row, [1] is column.
    selection_start = vim.current.buffer.mark('<')
    selection_end   = vim.current.buffer.mark('>')

    # if only one line is selected, last_line crop applies to already cropped
    # line, so it needs to crop `selection_start` less characters.
    if selection_start[0] == selection_end[0]:
        selection_end = selection_end[1] - selection_start[1]
    else:
        selection_end = selection_end[1]
    selection_start = selection_start[1]

    # crop out de-selected characters from the first and last lines.
    lines[0] = lines[0][selection_start:]
    last_line = len(lines)-1
    lines[last_line] = lines[last_line][:selection_end]

    # if it's python, optionally use cpaste (good for ipython) and 
    # unintend python source by default.
    if filetype == 'python':
        if unintend is True:
            lines = _vp_unintend_buffer(lines, vim.current.buffer[r.start])

        if use_cpaste is True:
            # TODO: use custom, unique string instead of default --
            lines.insert(0, '%cpaste')
            lines.append('--')

    # append one last \n so that so that we ensure code execution,
    # then construct the string, ready for paste into `VimuxRunner`.
    lines.append('')
    lines = "\n".join(lines)

    # if there's no Runner, create one; start default interpreter too.
    # TODO: also check `_VimuxHasRunner`
    # ALSO: if i'm going to use `RunCommand` anyway, it will fire up the 
    # Runner for me, hassle-free, no need for a check, hmm. What should I do
    # then if there's no interpreter (so no RunCommand) but also no Runner?
    # chicken out? this makes sense actually, at least we won't run random shit
    # in the default shell. but then again we loose re-use based on UseNearest.
    if _vp_runner_exists is True:
        open_runner = vim.Function('VimuxOpenRunner')
        open_runner()

        # TODO: if there is a defaut interpreter defined for a filetype, use it.
        # They are defined as g:vimux_paster_default_interpreter dictionary,
        # with filetype as the key. Problem: if VimuxUseNearest=1 (default) , we
        # could be reusing already existing pane/window as a runner, and it can
        # have the interpreter already running.
        # Also, if the filetype isn't some form of shell, and no interpreter is
        # defined, pasting the random code to the login shell is very silly,
        # that is unless it is already running and we are reusing Runner :)
        # Looks like there's no clear good way to avoid it, hmmm.
        if filetype == 'python':
            run_command = vim.Function('VimuxRunCommand')
            run_command('ipython')
        else:
            return

    send_text = vim.Function('VimuxSendText')
    send_text(lines)


def _vp_unintend_buffer(lines, first_line):
    """
        Unintend strings in `lines` list by as many whitespace characters as
        is present in the `first_lines`. Return a list of unintended strings.
    """

    # skip to first non-empty string to determine current intendation level.
    if len(first_line) == 0:
        for first_line in lines:
            if len(first_line) != 0:
                break

    # determine how many whitespace chars we need to strip.
    for nspaces, char in enumerate(first_line):
        if not char.isspace():
            break

    if nspaces > 0:
        for line_num, line in enumerate(lines):

            # if this is true, not the whole 1st line was selected,
            # so we don't need to unintend it.
            if line_num == 0 and line != first_line:
                continue

            # strip first `nspaces` chars
            lines[line_num] = line[nspaces:]

    return lines


def _vp_runner_exists():
    runner_index = vim.vars.get('VimuxRunnerIndex')
    vimux_has_runner = vim.Function('_VimuxHasRunner')
    return runner_index is None or vimux_has_runner(runner_index) == -1

endpython

vmap <leader>ve :python vimux_paster()<CR>gv

