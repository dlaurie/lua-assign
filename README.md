lua-assign: Find the best way of assigning jobs to persons.
===========================================================

Installation
------------

Copy `lua-assign.lua` to somewhere in `package.path`.

Testing
-------

While in the directory into which you cloned the repository, run `lua test-assign.lua`.

Usage:
------

    assign = require "lua-assign"
    task, skill = assign(scores[,option])

`scores`: A table with pairs `job,shortlist`, where `shortlist` is a table with pairs `person,score`, and `score` is a number. Numbers should be such that no precision is lost in addition, e.g. integers not too close to overflowing.

`task`: A table with pairs `person,job` where `person` is a key in `scores[job]` and each key in `scores` appears as `job` exactly once. If such an assignment does not exist, `nil` is returned unless `option` is given. The total of `scores[job][person]` over the pairs in `task` is a maximum. The table `task` has a metatable, see below.

`skill`: A table of numbers whose keys all appear in `task`, needed when calling `task`. If `task==nil`, `skill` is a message.

`option`:

1.  `assign(scores,"partial")` returns the most complete partial assignment that could be found. The returned values are maximal over the jobs actually assigned, not over all choices of jobs.
2.  `assign(scores,low)` means that every person who appears in any shortlist is treated as if on other shortlists too, with score `low`. The returned assignment may include pairs `person,job` for which `scores[job][person]` is nil.
3.  `assign(scores,"employ")` acts like `assign(scores,low)`, but `low` is calculated such that as many jobs as possible are assigned. Unlike `assign(scores,"partial")`, the assignment is maximal over all assignments that assign that number of jobs. The downside is that `assign(scores,"employ")` fills up the shortlists. If the original shortlists are sparse, `assign(scores,"partial")` is much faster.

### metamethods of `task`:

-   `__len`: `#task` returns the actual number of keys in `task`.
-   `__call`: `total, bound = task(scores,skill)` returns the total score
     of the assignment `task` and an upper bound based on `skill`. These
     are equal for the values returned by `assign(score)`, but not necessarily for the values returned by `assign(score,option)`. You can calculate `total,bound` for other inputs as follows:

        evaluate = getmetamethod(assign{}).__call
        total, bound = evaluate(task,scores,skill)

    If your input is invalid, `nil,message` is returned.

The fine print
--------------

Several of the loops use `pairs`, and some things are therefore not reproducible over different runs with the same data.

1.  If the maximal assignment is not unique, any maximal assignment may be returned.
2.  In the case of `assign(scores,"partial")`, the subset of jobs assigned is maximal in the sense that no jobs can be added to it without making the assignment impossible, and the total is maximal over that set, but the set itself is not always the same.

How it works
------------

For every job, one can work out a value `rating[job]` by calculating the largest difference `scores[job][person] - skill[person]`. Thus always

    scores[job][person] <= skill[person] + rating[job]

(If you add that up over a complete {job,person} assignment, the left side is the total score and the right side is always the same: the total skill plus the total rating. That's where the bound comes from.)

We say that a person is competent to do a job if

    scores[job][person] == skill[person] + rating[job]

(If you add up an assignment involving only competent persons, the total
equals the bound, and hence cannot be improved.)

The algorithm assigns the jobs one by one, making sure that all jobs are done by competent persons. That way the assignment is always maximal, even when incomplete. Once a person has a job, that person is never fired, but may be moved to a different job.

At the start, `task` and `skill` are empty.

1.  If the best person (i.e. the person determining the rating) on the
     shortlist for the new job is unemployed, the job is assigned to that person and we move on to the next job.
2.  If the best person already has a job, it gets complicated. The shortlist for that job is also examined, maybe other shortlists too. The question "If something is added to some of the current skill scores making the corresponding ratings go lower, which person would then be best?" is asked all the time. Sooner or later, we either find a way of rescheduling some of the jobs so that an unemployed person is best for one of the previously assigned jobs, or discover a subset of jobs whose combined shortlists do not contain enough persons. If successful, the skill scores are updated accordingly; if unsuccessful, the job is skipped.
3.  When the last job has been assigned or skipped, we are done.

The algorithm is a streamlined version of the [Hungarian algorithm] ([http://en.wikipedia.org/wiki/Hungarian\_algorithm](http://en.wikipedia.org/wiki/Hungarian_algorithm)), the main differences being:

-   the matrix may have more rows than columns;
-   the columns of the matrix are (thanks to Lua's table type) kept as sparse vectors;
-   the matrix itself is never updated, a vector of row corrections being updated instead (column corrections are implicit);
-   the solution process adds one column at a time, so that the partial solution is optimal on the partial matrix;
-   employment and/or performance is maximized instead of salaries being minimized (keeping both management and trade unions happy).

-
