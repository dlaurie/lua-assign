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
    nil, msg[, task, job] = assign(scores[,option])

`scores`: A table with pairs `job,shortlist`, where `shortlist` is a table with pairs `person,score`, and `score` is a number. Numbers should be such that no precision is lost in addition, e.g. integers not too close to overflowing, or fractions with a smallish power of 2 as denominator. 

`task`: A table with pairs `person,job` where `person` is a key in `scores[job]` and each key in `scores` appears as `job` exactly once. If such an assignment does not exist, `nil` is returned unless `option` is given. The total of `scores[job][person]` over the pairs in `task` is a maximum. The table `task` has a metatable, see below.

`skill`: A table of numbers whose keys all appear in `task`, needed when calling `task`. 

If the first return value is `nil`, an error message is returned. If it says something about a subset, the current `task` and the job that could not be added are the third and fourth return values.

`option`:

1.  `assign(scores,"partial")` returns the most complete partial assignment that could be found. The returned values are maximal over the jobs actually assigned, not over all choices of jobs.
2.  `assign(scores,low)` means that every person who appears in any shortlist is treated as if on other shortlists too, with score `low`. The returned assignment may include phony jobs, i.e. pairs `person,job` for which `scores[job][person]` is nil. The lower you make `low`, the fewer of these phony jobs appear.
3.  `assign(scores,"employ")` acts like `assign(scores,low)`, but `low` is calculated to be low enough that as many genuine jobs as possible are assigned. This is similar to what `assign(scores,"partial")` does, except that:

   - Every job appears to be assigned to somebody. You need to examine `scores[job][person]` yourself to find the phony jobs.
   - The assignment is maximal over all ways to choose that number of jobs, whereas `partial` is only maximal over the set of jobs actually assigned.
   - If the original shortlists are sparse, `assign(scores,"partial")` is faster.

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

All table traversals use `next`, and some things are therefore not reproducible over different runs with the same data.

1.  If the maximal assignment is not unique, any maximal assignment may be returned.
2.  In the case of `assign(scores,"partial")`, the subset of jobs assigned is maximal in the sense that no jobs can be added to it without making the assignment impossible, and the total is maximal over that set, but the set itself is not always the same.

How it works
------------

For every job, one can work out a value `rating[job]` by calculating the largest difference `scores[job][person] - skill[person]`. Thus always

    scores[job][person] <= skill[person] + rating[job]

If you add that up over a complete {job,person} assignment, the left side is the total score and the right side is always the same: the total skill plus the total rating. That's where the bound comes from.

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

The algorithm is a streamlined version of the [Hungarian algorithm]([http://en.wikipedia.org/wiki/Hungarian\_algorithm](http://en.wikipedia.org/wiki/Hungarian_algorithm)), the main differences being:

-   the matrix may have more rows than columns;
-   the columns of the matrix are (thanks to Lua's table type) kept as sparse vectors;
-   the matrix itself is never updated, a vector of row corrections being updated instead (column corrections are implicit);
-   the solution process adds one column at a time, so that the partial solution is optimal on the partial matrix;
-   employment and/or performance is maximized instead of salaries being minimized.

Other applications
------------------

"Job" and "person" are of course only names for two kinds of stuff that you wish to pair off, having at least as many of the second as of the first.

- If you have more jobs than people, treat a job as "person" and a person as "job".
- If you wish to minimize rather than maximize, change the sign of the scores.
- Mathematically, what we are maximizing is $\sum_k w(k,p_k)$ where $w$ is some function of two variables, over all possible permutations $p.$

The assignment problem is a special case (supply and demand always one unit) of the transportation problem:

> A certain commodity, measured in units, is available at depots and required by customers. For each depot/customer combination, the unit cost of shipping an item is known. Calculate the cheapest way of doing the full shipping job.

If the numbers involved are fairly small, one can use `lua-assign` to solve the transportation problem by simply duplicating depots and customers.


