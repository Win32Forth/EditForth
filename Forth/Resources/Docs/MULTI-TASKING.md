# Multi-tasking

**Status:** steps 1–3 are in the Mac kernel. Steps 4–6 are not implemented. Cold start is `SINGLE`.
**Scope:** Mac EditForth (`Forth/Kernel/forth.s`, `Forth/Kernel/kernel2.fth`, `Forth/Host/KernelBridge.swift`). EditForthPWA stays one thread.
**Source:** Brad Rodriguez, [Forth Multitasking in a Nutshell](https://www.bradrodriguez.com/papers/mtasking.html) (September 1992).

One task model, two schedulers. Cooperative is the default. Multi-core is a later placement of the same task records. A task runs until it yields. The operating system does not preempt inside `NEXT` or inside a `CODE` word.

## Step 1 as built

`PAUSE` is high-level: `(YIELD)` then `(PAUSE-HOOK)`. `(YIELD)` switches only when `MULTI` is on, some other task is awake, and the debugger is not armed, busy, or requesting Break Now. Otherwise it is a no-op, and `(PAUSE-HOOK)` still flushes the console and waits 1 ms. `DBG-PAUSE` is untouched.

`KEY` uses that same switch test, and only when a `KEY?` hook is installed and reports no key waiting. With no hook, `KEY` blocks as before. The waiting task resumes through a per-task trampoline so the rest of `KEY` still runs.

`TASK:` refuses a name that already exists, then `CREATE`s and `(TASK-INIT)` allots the block at `HERE`: a 256-byte user area, a 512-cell data stack, a 512-cell return stack, and 3264 bytes of private scratch. That is 11712 bytes. The task is asleep until `ACTIVATE`. Each new task is linked immediately after the console, so the newest task runs first, and the circle returns to the console.

`ACTIVATE` is valid only inside a colon definition. It sets the task's instruction pointer to the body that follows, empties that task's data stack, plants a `STOP` sentinel on its return stack, copies the current `BASE`, sets `STATE` to zero, marks the task awake, and returns to the caller of the defining word. It does not switch yet. The task starts at the next yield. A body that returns hits `STOP` and then parks. `WAKE` of a finished task resumes that park. It does not rerun the old body.

`STOP` of the console prints `STOP: the console task stays awake` and continues. `SLEEP` of the console, when it is the only awake task, prints `SLEEP: the console is the only awake task`, drops the task address, and continues.

`FORGET` and `ANEW` unlink every task whose user area is at or above the cut before the dictionary is reclaimed. The console record is not in the dictionary. The walk stops when it returns to that record.

`GROWMEMORYMB` from any task other than the console prints `? GROWMEMORYMB only from the console task` and `STOP`s that task. The console line continues, and the once-per-session flag is not consumed.

`BASE` and `STATE` are saved and restored with the task. A background task runs an already-compiled body. It does not `INCLUDE`, load a block, or compile.

The sample is `Forth/Resources/Library/Sample/TASKCLOCK.fth`. On the Debug kernel, 20 console `PAUSE`s advanced the counter by 20, `SINGLE` held it, `STOP` held it, `WAKE` added one tick per further `PAUSE`, a background `GROWMEMORYMB` was refused, and `ANEW` removed both tasks. The same counts held after step 2. With `MULTI` left off, ANS-VALIDATE reported 395 passed, 0 failed.

## Step 2 as built

Each task has its own `word_scratch` (512 bytes), `PAD` (1024), input buffer (1024), source stack (640), and evaluate-resume stack (64). Those bytes sit after the two stacks. The user area holds pointers to them. `HLD` is a cell in the user area, and `HLD` returns that cell. `<#` stores `PAD 256 +` there. `SOURCE`, `>IN`, `SOURCE-ID`, `BLK`, the line window, the parse cursor, and the source-stack depth are cells in the same record.

The console pointers aim at the existing BSS buffers, so a single-task session uses the same addresses as before. Background pointers aim into that task's block. The 256 KiB file buffer and the block buffer stay shared.

`ACTIVATE` zeros the source cells through the evaluate-stack pointer and leaves the buffer pointers in place, so a second `ACTIVATE` does not parse the previous `SOURCE`.

`(SOURCE!)` `( c-addr u -- )` sets the running task's `SOURCE`, zeros `>IN`, and clears the line window. A compiled body uses it before `WORD`. On the console it replaces the file being interpreted, so a console call belongs at the end of that input.

`0BRANCH` and `EXECUTE`'s empty-stack test compare the data-stack pointer with this task's `S0`. `DEPTH`, `SP0`, and `CLEARSTACK` use that same `S0` and the 4096 bytes below it. The interpreter's between-word stack check and the console prompt still name the console data stack.

`INCLUDE`, `INCLUDED`, `REQUIRED`, `(INCLUDE)`, and `(LINE-SOURCE)` from a background task print `? INCLUDE only from the console task` and `STOP`. `LOAD` and `BLOCK` print `? block load only from the console task` and `STOP`. The console line continues.

The sample is `Forth/Resources/Library/Sample/TASKSCRATCH.fth`. Two tasks each parsed a different name and pictured a different number. A `PAUSE` sat between `WORD` and the copy, and inside `<#` … `#>`. The run printed `alpha-one`, `beta-two`, `111`, `222`, and `scratch-ok`, then both refuse lines, `refuse-returned`, `single-ok`, and `depth=0`.

## Step 3 as built

A semaphore is one aligned cell. `1` is free and `0` is taken. `CLAIM` does an exclusive load. It stores `0` only while this core still holds the reservation, and returns true (`-1`). A cell that is already `0` returns false and is not written. `RELEASE` stores `1` with a release store. `SIGNAL` is `RELEASE`, then the same yield `PAUSE` uses. `WAIT` repeats `CLAIM`. While the cell is `0` and another task can run, it yields and resumes on a retry, with the following word saved in the same user-area cell `KEY` uses. A task does not `WAIT` from inside `KEY`.

If `MULTI` is off, or no other task is awake, `WAIT` prints `? WAIT: no other task can SIGNAL`, drops the address, and does not take the semaphore.

A second `SIGNAL` before the matching `WAIT` stores `1` again. The cell does not count. The sample hands off one signal at a time, so each `SIGNAL` is claimed once.

`GRAPHICS-SEM`, `CONSOLE-SEM`, and `DICT-SEM` are the three device cells. They start free. Cold init sets them back to `1`. The kernel does not take them inside `EMIT`, a blit, or header linking. A task that claims one releases it before `WAIT`.

The sample is `Forth/Resources/Library/Sample/TASKSEM.fth`. Console `CLAIM` printed `-1`, `0`, `-1`. The device cells printed `1`, `0`, `1`, `1`, then the stuck-wait line and `wait-stuck-ok`. Two tasks then printed `hits1=1`, `hits2=1`, `hits3=2`, `hits4=2`, `hits5=2`, `hits6=3`, `sem-ok`, and `depth=0`. `TASKCLOCK.fth` still passed. With `MULTI` left off, ANS-VALIDATE reported 395 passed, 0 failed.

## What a task is

A task is one Forth program with its own data stack, return stack, and user area. The programs share one dictionary. The console is a task. Extra tasks are background work: a clock, a counter, a producer, a consumer.

The running task is `up_var` in BSS. There is no new virtual-machine register. A `USER` word loads `up_var` and adds an offset.

The yield saves four registers into the user area and loads the next awake task:

- `x19` instruction pointer
- `x20` top of stack
- `x22` data-stack pointer
- `x23` return-stack pointer

`x24` (`latest`) stays shared. A sleeping task is skipped by its status cell. The switch runs only between Forth words.

User-area fields:

- link to the next task
- status (awake or asleep)
- the four saved registers
- `S0` and `R0`
- `BASE` and `STATE`
- pointers to `word_scratch`, `PAD`, the input buffer, the source stack, and the evaluate-resume stack
- `HLD`, `SOURCE`, `>IN`, `SOURCE-ID`, `BLK`, the line window, the parse cursor, and the source-stack depth

The console user area is a fixed BSS record. Its stacks are the existing `data_stack` and `return_stack` (512 cells each). Its scratch pointers aim at the existing global buffers, so a single-task session uses the same addresses as today.

## Dictionary and HERE

`TASK:` allots a background task's user area and two stacks from the shared dictionary. The console `HERE` moves past that block and further console definitions compile there.

A background task runs an already-compiled word. It does not get its own `HERE`. A private dictionary slice is a later step, and only if a background task must `CREATE` or `ALLOT`. That slice would sit inside the task block, with its own `HERE` and limit. The console `HERE` would already be past the whole block.

`WORD` does not write at `HERE`. It writes `word_scratch`. Compiled bytes below `HERE` stay put while tasks run. Two tasks that both compile would share the one `HERE`, so background tasks do not compile until the private-slice step.

`FORGET` and `ANEW` unlink any task whose user area is at or above the cut before reclaiming that memory. The console task is a BSS record, so a dictionary cut cannot remove it. The unlink runs before the space is reused.

## GROWMEMORYMB

`GROWMEMORYMB` raises the logical end of the one shared dictionary. The base `user_dict_area` does not move, so code-field addresses stay valid. The logical size starts at 8 MiB. The process reserve is 256 MiB, demand-zero. The word accepts 1 through 256, once per session, and only when the new size is larger.

Two rules are added for tasks:

- Only the console task may call `GROWMEMORYMB`. A call from any other task prints `? GROWMEMORYMB only from the console task` and `STOP`s that task. The console evaluate is not abandoned.
- The console calls it before the allotments that need the extra room. Raising the fence later is safe for tasks that already exist, because the base does not move, but the once-per-session rule still applies.

The size rules do not change. There is no per-task heap and no per-core reserve. The 256 MiB cap is the process cap.

## Scratch buffers

These follow the running task. The multi-core scheduler stays off.

- `word_scratch` (512 bytes). `BL WORD` stores the counted name here and clamps the name to 63 characters. The address lasts until that same task's next `WORD`.
- `PAD` (1024 bytes) and `HLD`. `<#` `#` `HOLD` `#>` use them.
- `SOURCE`, `>IN`, `SOURCE-ID`, the source stack, and the line window.
- A private input buffer for `ACCEPT` and `EVALUATE`.

The 256 KiB `file_buffer` and the block buffer stay shared. Only the console task `INCLUDE`s or loads a block.

## Words

| Word | Effect |
| --- | --- |
| `TASK:` | Allot the user area and two stacks, link the task. Refuse a second create of the same task. |
| `ACTIVATE` | Set the new task's instruction pointer to the high-level body that follows. Used inside a definition, not while interpreting. The body loops, or ends in `STOP`. |
| `SLEEP` | Mark a task asleep. |
| `WAKE` | Mark a task awake. |
| `STOP` | Sleep the running task and yield. |
| `MULTI` | Arm the yield. |
| `SINGLE` | Make the yield a no-op. The task that executes it keeps the core until `MULTI`. |
| `PAUSE` | Unchanged meaning: flush the console, then wait 1 ms. When `MULTI` is on, yield first. `DBG-PAUSE` is untouched. |
| `CLAIM` | `CODE`. Exclusive load/store. Store zero only if this core still holds the reservation. A busy flag returns false and is not written. |
| `RELEASE` | `CODE`. Store one with a release store. |
| `WAIT` | Repeat `CLAIM`. Park while it fails. |
| `SIGNAL` | `RELEASE`, then yield so a waiting task can `CLAIM`. |
| `GRAPHICS-SEM` | Address of the graphics-map semaphore. `1` is free. |
| `CONSOLE-SEM` | Address of the console-emit semaphore. `1` is free. |
| `DICT-SEM` | Address of the dictionary-mutation semaphore. `1` is free. |

`KEY`, while it waits and another task is awake, yields instead of sleeping the whole machine.

On the cooperative scheduler the park inside `WAIT` is the yield. On the multi-core scheduler the park suspends that task's queue. A failed claim does not spin.

## Schedulers

**Cooperative.** One virtual machine, one queue (`64Forth.kernel`). This is the default. A sample can activate a loop that increments a counter and calls `PAUSE`, and the console still accepts the next line.

**Multi-core.** The same records and the same mailbox words. A mode word selects it. The console stays on `64Forth.kernel`. Each awake compute task gets its own serial queue at user-initiated quality of service, which prefers a performance core and does not pin one. At most four compute workers run at once. A fifth awake compute task shares a worker.

`EMIT`, `KEY`, and `PREFRESH` from a background task are posted to the console queue, and that task waits. `evalLock` stays: a second console line is rejected while one evaluate holds the console task. The debugger stays on the console task. `x28` and `debug_armed` are not copied onto background tasks.

Before multi-core can be switched on, `CODE` words that keep per-execution scratch in BSS are either left console-only or moved to the CPU stack or the user area. A background task calls only that audited subset.

## Tasks talking to each other

`CLAIM` and `RELEASE` are `CODE` words from the first semaphore, so the same words are correct on one core and on several. A high-level test followed by a separate store lets two cores both see a free flag.

Device semaphores, one each:

- graphics map
- console emit buffer
- dictionary mutation (`HERE` and header linking)

A task releases a device semaphore before it waits for another task. Holding the graphics lock or the dictionary lock while waiting for the other side to produce a message deadlocks.

A mailbox is a value plus a full/empty pair, allotted once. The sender writes the value, then signals full. The receiver waits, reads, then signals empty. The value store happens before the release store. Traffic does not move `HERE`.

A one-producer, one-consumer queue is a fixed ring. The producer fills a slot, then publishes the tail with a release store. The consumer acquire-loads the tail, reads the slot, then publishes the head. Two producers or two consumers take a semaphore around reserving the slot.

One aligned cell may be published with a plain store. A second cell, a counted string, or a record goes through a mailbox.

## Steps

1. **Cooperative round robin.** Landed. `TASK:` `ACTIVATE` `SLEEP` `WAKE` `STOP` `MULTI` `SINGLE`, the yield inside `PAUSE` and `KEY`, and the `FORGET` / `ANEW` unlink. `GROWMEMORYMB` refuses a caller that is not the console task. Background tasks only run an already-compiled body. See "Step 1 as built".
2. **Per-task scratch.** Landed. `WORD`, `PAD`, pictured numbers, and `SOURCE` / `>IN` follow the running task. `INCLUDE` and block load stay on the console. See "Step 2 as built".
3. **Semaphores.** Landed. `CLAIM` `RELEASE` `WAIT` `SIGNAL`, plus `GRAPHICS-SEM`, `CONSOLE-SEM`, and `DICT-SEM`. See "Step 3 as built".
4. **Mailbox and queue.** Fixed rings in the shared dictionary.
5. **Multi-core scheduler.** Off by default. Console queue unchanged. Compute tasks on their own queues, capped at four.
6. **Private dictionary slice.** Only if a background task must compile. Not part of the first working tasker.

## Checks

- One task and `MULTI` off: `PAUSE` still flushes and returns. Passed (`pause-ok` in `TASKCLOCK.fth`, and ANS-VALIDATE 395 passed, 0 failed).
- A counter task advances while the console accepts a line. `SINGLE` freezes it. `STOP` removes it from the rotation. Passed (20 pauses → 20, then the count held, then `WAKE` added one per pause).
- `ANEW` of a file that created a task unlinks it, and the circle still reaches the console. Passed (`clock-gone`, `gmm-gone`, then pauses after the old blocks were overwritten).
- Two tasks can each `BL WORD` and `<# #S #>` without seeing the other's text. Passed (`TASKSCRATCH.fth`: `alpha-one` / `beta-two`, `111` / `222`, `scratch-ok`). A background `INCLUDE` and `LOAD` printed the refuse lines and returned to the console.
- A flag passed between two tasks delivers every `SIGNAL` once. Passed (`TASKSEM.fth`: hits `1`, `1`, `2`, `2`, `2`, `3`, then `sem-ok`). A pause with no new `SIGNAL` left the count unchanged.
- A producer and a consumer move several thousand cells with no loss, no duplicate, and a bounded depth.
- ANS-VALIDATE stays a single-task run. Repeat it after steps 1 and 2, and again before the multi-core mode is left available.
- With the multi-core mode on, two counting loops overlap, exchange counts through the queue, and the console still accepts a line. Cooperative mode still passes the earlier checks.
- `GROWMEMORYMB` from a background task is refused, and the console line continues. Passed. From the console it still grows once, refuses a shrink, and refuses a second call. Those console size checks were already in the kernel and were not re-run as part of this step.

## Out of scope

- EditForthPWA, wasm workers, and shared-memory browser threads.
- Preemption inside `NEXT`.
- A private `HERE` for every task.
- Replicating the debugger onto background tasks.
- Changing the once-per-session, no-shrink, or 256 MiB rules of `GROWMEMORYMB`.
- Per-core dictionaries or a second 256 MiB reserve.
