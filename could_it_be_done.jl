
# (Written for Julia 0.6.0)

NUMBERS_COUNT = 6
MAX_BIGGUNS   = 4
padding_spaces = [("  " ^ (n-1)) * "* " for n in 1:NUMBERS_COUNT]

"""
could_it_be_done(target, numbers[, verbosity]) -> (is_achievable, achieved_target)

Solves the Numbers game from the TV show Countdown.

Returns whether a point-gaining solution could be achieved, along with the actual
achieved target (either the given target, or the closest achievable number
not more than 10 away from original target).

If the given numbers are solvable (and verbosity allows it), prints the steps of
the solution in human-readable style.

# Arguments 
- `target`: should be a number between 101 and 999.
- `numbers`: should be one of: `[1:10 25 50 75 100]`
- `verbosity`: <=0 for no output, 1 for normal output, >=2 for debug output. Default: 1

# Examples

```jldoctest

julia> could_it_be_done(375, [5, 3, 100, 25, 50, 75])

You could have said:
-Take the 5
-Take the 75
-Multiply those together to get 375
(true, 375)

julia> could_it_be_done(243, [5, 3, 100, 25, 50, 75], verbosity=0)
(true, 243)

julia> could_it_be_done(989, [5, 3, 100, 25, 50, 75], verbosity=0)
(true, 990)

# difficult but possible
julia> could_it_be_done(952, [6, 3, 100, 25, 50, 75], verbosity=0)
(true, 952)

julia> could_it_be_done(921, [5, 5, 1, 2, 3, 1], verbosity=0)
(false, nothing)

```

"""
function could_it_be_done(target, numbers; verbosity=1)
    validate_input(target, numbers)

    solution = find_arithmetic_expr(target, numbers)

    # if target is not doable, try to get the closest valid number that is doable
    away = 0
    if (solution == nothing)
        verbosity > 0 && print("Couldn't find $target from the given numbers. ")
        while (solution == nothing) && (-10 <= away <= 10)
            away = (away <= 0) ? (-away + 1) : (-away) # Go 1 to -1 to 2 to -2 to 3 to ...
            nearby_target = target + away
            verbosity > 0 && print("Trying to get $nearby_target now... ")
            solution = find_arithmetic_expr(nearby_target, numbers)
        end
    end

    verbosity > 0 && tell_them(solution, target, away)

    is_achievable = (solution != nothing)
    achieved_target = is_achievable ? target + away : nothing
    return (is_achievable, achieved_target)
end

# FIXME there's gotta be a better way to do this
array_rem_idx(arr, idx) = (arr[[1:(idx-1); (idx+1):end]])

function verify_solution(s, t) 
    #print("Sol ", s, "\n") #DBG
    @assert (eval(s) == t) "Attempted solution $(s) doesn't evaluate to $(t), instead to $(eval(s))"
end

#= find_arithmetic_expr

Given a target number and an array of initial numbers to work with, figures out
an arithmetic expression involving those initial numbers and the four basic 
arithmetic operators (+, -, *, /), that equals the final number.

Does that by working backward from the target number, trying to break it down into
the given set of numbers in some way. 

(Note: 
Number of potential expressions given n numbers and 4 binary operations 
= nC2 * 4 + nC3 * 4 * 4 + ... + nCn * (4)^(n-1)
= sum( nCk * (4)^(k-1) ) given k = 2 to n
= sum_(k=2)^n 4^(k - 1) binomial(n, k) = 1/4 (-4 n + 5^n - 1) #Wolfram Alpha
which given n = 6 comes to 3900.  
Therefore, a naive brute force version would create and evaluate 3900 expressions
using the given numbers.)
=#
function find_arithmetic_expr(target, numbers)::Union{Expr, Void}
    if target in numbers
        #return it raised to power one so it remains Expr and doesn't autoreduce to Int
        return :($target ^ 1) 
    elseif length(numbers) == 1
        return nothing
    end

    leftpad = padding_spaces[NUMBERS_COUNT - length(numbers) + 1]
    #print("\n$(leftpad)Trying for target $(target) using $(numbers)...") #DBG

    # Try to simplify the target by looking for factors among the numbers
    solution = look_for_factors(target, numbers)
    (solution != nothing) && return solution

    opers = [:*, :+]
    solution = try_pairwise_arith(target, numbers, opers)
    (solution != nothing) && return solution

    opers = [:-, :/]
    solution = try_pairwise_arith(target, numbers, opers)
    (solution != nothing) && return solution

    return nothing
end

function look_for_factors(target, numbers)
    if length(numbers) == 1
        # if there are no other numbers left to form a multiplicand with
        return nothing #assume equality to target has already been checked
    end
    for (idx, n) in enumerate(numbers)
        if target % n == 0 && n != 1
            unused_nums = array_rem_idx(numbers, idx)

            partial_soln = find_arithmetic_expr(div(target, n), unused_nums)
            if partial_soln != nothing
                solution = :($n * $partial_soln)
                verify_solution(solution, target)
                return solution
            end
        end
    end
end

function try_pairwise_arith(target, numbers, opers)
    for (idx, n) in enumerate(numbers)
        n = Unsigned(n) #assertion that the value is non-negative
        for idx2 in (idx+1):length(numbers)
            m = Unsigned(numbers[idx2])
            unused_nums = array_rem_idx(array_rem_idx(numbers, idx2), idx)
            for oper in opers
                if n < m && oper in [:-, :/]
                    pair_expr = :($oper($m, $n))
                else
                    pair_expr = :($oper($n, $m))
                end
                pair_result = eval(pair_expr)

                # only positive integers may be obtained as a result at any stage of the calculation.
                # (Countdown (game show), Wikipedia, in turn from 'Countdown: Spreading the Word' (2001) p. 24.)
                if pair_result <= 0 || round(pair_result) != pair_result
                    continue
                else
                    pair_result = Unsigned(pair_result) #division gives Float, turn back to int
                    if pair_result == target
                        solution = pair_expr
                        verify_solution(solution, target)
                        return solution
                    elseif length(unused_nums) == 0
                        continue
                    end
                end

                if (pair_result < target) 
                    diff = (target - pair_result) 
                    # partial solution should be added to result to get target
                    partial_soln = find_arithmetic_expr(diff, unused_nums)
                    if partial_soln != nothing
                        solution = :($pair_expr + $partial_soln)
                        verify_solution(solution, target)
                        return solution
                    end
                else
                    diff = (pair_result - target)
                    # partial solution should be subtracted from result to get target
                    partial_soln = find_arithmetic_expr(diff, unused_nums)
                    if partial_soln != nothing
                        solution = :($pair_expr - $partial_soln)
                        verify_solution(solution, target)
                        return solution
                    end
                end

                quot = -1
                if pair_result < target && target % pair_result == 0
                    quot = Unsigned(target/pair_result)
                    # partial solution and pair result should be multiplied to get target
                    partial_soln = find_arithmetic_expr(quot, unused_nums)
                    if partial_soln != nothing
                        solution = :($pair_expr * $partial_soln)
                        verify_solution(solution, target)
                        return solution
                    end
                elseif pair_result > target && pair_result % target == 0
                    quot = Unsigned(pair_result/target)
                    # pair result should be divided by partial solution to get target
                    partial_soln = find_arithmetic_expr(quot, unused_nums)
                    if partial_soln != nothing
                        solution = :($pair_expr / $partial_soln)
                        verify_solution(solution, target)
                        return solution
                    end
                end

                #= say target = 41, numbers = [1, 3, 9, 5]
                1 + 3 = 4 (this will be the pair_result),
                41 + 4 = 45 (sum_value),
                then 45 can be found as product as 9 and 5 in recursion. =#
                sum_value = target + pair_result
                partial_soln = find_arithmetic_expr(sum_value, unused_nums)
                if partial_soln != nothing
                    # solution should then be stored as (9 * 5) - (1 + 3)
                    solution = :($partial_soln - $pair_expr)
                    verify_solution(solution, target)
                    return solution
                end

                # TODO target * pair_result should be found, then solution would be (partial_soln/pair_expr)

            end
        end
    end

    return nothing
end

tell_them(solution::Void, t, a) = println("This one's impossible. Sorry!")

function tell_them(solution::Expr, target, away)

    #= 
    if length(solution) == 1 && solution[1] isa Unsigned
        print("You've already got a $(solution[1]), no hard work!\n")
        return
    end
    =#

    result = UInt16(eval(solution))
    achieved_target = target + away
    @assert (result == achieved_target) "Something went wrong: I thought I had $achieved_target, but I have $result instead."

    println("\n[Raw solution: \n$(solution)\n = $(result).]") #DBG

    println("You could have said:")
    say_expr(solution, level=1)

    if (away != 0) 
        away = abs(away)
        println("\n$away away from $target.")
    end
    println()
end

function say_expr(solution; level=1)
    oper       = solution.args[1]
    operands   = solution.args[2:end]
    soln_value = Unsigned(eval(solution))
    leftpad    = padding_spaces[level]

    #println("oper = $oper , operands = $operands , value = $soln_value") #DBG 

    # Special case
    if oper == :^
        if length(operands) != 2 || operands[2] != 1
            error("Something went wrong: attempted solution $solution uses exponentiation, illegal!")
        end
        operands = [operands[1]]
    end

    operand_vals = []
    for el in operands
        if el isa Number
            println(leftpad, "Take the $el")
            operand_vals = push!(operand_vals, el)
        elseif el isa Expr
            el_value = Unsigned(eval(el))
            if el.args[1] == :^
                say_expr(el, level=level)
            else
                println(leftpad, "Get $(el_value) this way:")
                say_expr(el, level=level+1)
            end
            operand_vals = push!(operand_vals, el_value)
        else
            error("Encountered unexpected value $el of type $(typeof(el)) when trying to print solution $solution.")
        end
    end

    if oper == :+
        println(leftpad, "Add those together to get $soln_value")
    elseif oper == :*
        println(leftpad, "Multiply those together to get $soln_value")
    elseif oper == :-
        # - and / take only two operands
        println(leftpad, "Subtract $(operand_vals[2]) from $(operand_vals[1]) to get $soln_value")
    elseif oper == :/
        println(leftpad, "Divide $(operand_vals[1]) by $(operand_vals[2]) to get $soln_value")
    elseif oper == :^
        ; #nothing to do, since it's always ^1
    else
        error("Encountered unexpected operator $oper when trying to print solution $solution.")
    end
end

function validate_input(target, numbers)
    if length(numbers) != NUMBERS_COUNT
        error("We should have $(NUMBERS_COUNT) initial numbers to work with, instead we have $(length(numbers)).")
    end

    # "An electronic computer called CECIL selects a target number from 101 to 999 inclusive at random."
    # (http://www.ukgameshows.com/ukgs/Countdown)
    if !(101 <= target <= 999)
        error("Are you trying to have a go at me, mate? The target should be between 101 and 999, not $(target).")
    end

    is_valid_input_num(n) = ((1 <= n <= 10) || n in [25, 50, 75, 100])
    if !all(is_valid_input_num, numbers)
        error("Something's wrong here: you can have only numbers 1 to 10 or numbers 25, 50, 75 and 100 as initial numbers to work from.")
    end

    bigguns = filter(n -> n > 10, numbers)
    if length(bigguns) > MAX_BIGGUNS || !allunique(bigguns)
        error("You can have $(MAX_BIGGUNS) bigguns at most, and they can't repeat (input had these: $bigguns)")
    end
end

