
# (Written for Julia 0.6.0)

using Combinatorics

NUMBERS_COUNT   = 6
MAX_BIGGUNS     = 4
OPERS           = [:*, :+, :-, :/]
padding_spaces  = [("  " ^ (n-1)) * "* " for n in 1:NUMBERS_COUNT]
verbosity_level = 1

macro if_verbose(code)
    quote
        if verbosity_level > 0 
            $(esc(code))
        end
    end
end

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

    global verbosity_level
    verbosity_level = verbosity 

    solution = find_arithmetic_expr(target, numbers)

    # if target is not doable, try to get the closest valid number that is doable
    away = 0
    if (solution == nothing)
        @if_verbose print("Couldn't find $target from the given numbers. ")
        while (solution == nothing) && (-10 <= away <= 10)
            away = (away <= 0) ? (-away + 1) : (-away) # Go 1 to -1 to 2 to -2 to 3 to ...
            nearby_target = target + away
            @if_verbose print("Trying to get $nearby_target now... ")
            solution = find_arithmetic_expr(nearby_target, numbers)
        end
    end

    @if_verbose tell_them(solution, target, away)

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

    # Try to simplify the target by looking for factors among the numbers
    solution = look_for_factors(target, numbers)
    (solution != nothing) && return solution

    solution = try_all_combinations(target, numbers)
    (solution != nothing) && return solution

    return nothing
end

function look_for_factors(target, numbers)
    if length(numbers) == 1
        # if there are no other numbers left to form a multiplicand with
        return nothing #assume equality to target has already been checked
    end
    # TODO ? return two arrays - one of them unused_nums - instead of doing recursion here
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

function try_all_combinations(target, numbers)
    for n = 2:length(numbers)
        number_combs = multiset_combinations(numbers, n)
        oper_orders  = get_oper_orderings(OPERS, n-1)
        for nc in number_combs
            for oper_comb in oper_orders
                for oper_perms in oper_comb
                    result = evaluate(nc, oper_perms)
                    if result == target
                        return make_expr(nc, oper_perms)
                    end
                end
            end
        end
    end
end

function get_oper_orderings(opers::Array{Symbol}, n)
    combs = with_replacement_combinations(opers, n)
    orderings = [multiset_permutations(c, n) for c in combs]
    return orderings
end

function evaluate(numbers, operators)
    result = eval(operators[1])(numbers[1], numbers[2])
    for (idx, op) in enumerate(operators[2:end])
        result = eval(op)(result, numbers[idx+1])
    end
    return result
end

function make_expr(numbers, operators)
    result_expr = Expr(:call, $(operators[1]), $(numbers[1]), $(numbers[2]))
    for (idx, op) in enumerate(operators[2:end])
        result_expr= Expr(:call, $op, $result, $(numbers[idx+1]))
    end
    return result_expr
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

