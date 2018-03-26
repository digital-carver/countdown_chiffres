
# (Written for Julia 0.6.0)

NUMBERS_COUNT = 6
MAX_BIGGUNS   = 4
function could_it_be_done(target, numbers)::Bool
    validate_input(target, numbers)

    solution = find_arithmetic_expr(target, numbers)

    # if target is not doable, try to get the closest valid number that is doable
    print("Couldn't find $target from the given numbers. ")
    away = 0
    while (solution == nothing) && (-10 <= away <= 10)
        away = (away <= 0) ? (-away + 1) : (-away) # Go 1 to -1 to 2 to -2 to 3 to ...
        print("Trying to get $nearby_target now... ")
        nearby_target = target + away
        solution = find_arithmetic_expr(nearby_target, numbers)
    end

    tell_them(solution, target, away)

    return (solution != nothing)
end

# FIXME there's gotta be a better way to do this
array_rem_idx(arr, idx) = (arr[[1:(idx-1); (idx+1):length(arr)]])

function verify_solution(s, t) 
    #print("Sol ", s, "\n") #DBG
    @assert (eval(s) == t) "Attempted solution $(s) doesn't evaluate to $(t), instead to $(eval(s))"
end

#=
find_arithmetic_expr(target, numbers) -> Expr

Given a target number and an array of initial numbers to work with, figures out
an arithmetic expression involving those initial numbers and the four basic 
arithmetic operators (+, -, *, /), that equals the final number.

Does that by working backward from the target number, trying to break it down into
the given set of numbers in some way. 

Note: 
Number of potential expressions given n numbers and 4 binary operations 
(excluding when target is one of the numbers) 
 = nC2 * 4 + nC3 * 4 * 4 + ... + nCn * (4)^(n-1)
 = sum( nCk * (4)^(k-1) ) for k = 2 to n
 = sum_(k=2)^n 4^(k - 1) binomial(n, k) = 1/4 (-4 n + 5^n - 1) #Wolfram Alpha
which for n = 6 comes to just 3900. So, even just brute forcing through 
evaluating 3900 expressions would be doable. 

=#
function find_arithmetic_expr(target, numbers)::Union{Expr, Void}
    if target in numbers
        #return it raised to power one so it remains Expr and doesn't autoreduce to Int
        return :($target ^ 1) 
    elseif length(numbers) == 1
        return nothing
    end

    solution = nothing
    leftpad = " " ^ (NUMBERS_COUNT - length(numbers))
    print("\n$(leftpad)Trying for target $(target) using $(numbers)...") #DBG

    # Try to simplify the target by looking for factors among the numbers
    solution = look_for_factors(target, numbers)
    (solution != nothing) && return solution

    opers = [:*, :+]
    solution = try_pairwise_arith(target, numbers, opers)
    (solution != nothing) && return solution

    opers = [:-, :/]
    solution = try_pairwise_arith(target, numbers, opers)
    (solution != nothing) && return solution

    return solution
end

function look_for_factors(target, numbers)
    for idx in eachindex(numbers)
        n = numbers[idx]
        if target % n == 0 
            unused_nums = array_rem_idx(numbers, idx)
            if length(unused_nums) == 0
                continue
            end

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
    for idx in eachindex(numbers)
        n = UInt(numbers[idx])
        for idx2 in (idx+1):length(numbers)
            m = Unsigned(numbers[idx2])
            unused_nums = array_rem_idx(array_rem_idx(numbers, idx2), idx)
            for oper in opers
                if n < m && oper in [:-, :/]
                    pair_expr = Expr(:call, oper, m, n)
                else
                    pair_expr = Expr(:call, oper, n, m)
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

tell_them(solution::Void, t, a) = print("This one's impossible. Sorry!\n")

function tell_them(solution::Expr, target, away)

    #= print("You could have said:\n")
    if length(solution) == 1 && solution[1] isa Unsigned
        print("You've already got a $(solution[1]), no hard work!\n")
        return
    end
    =#

    result = UInt16(eval(solution))
    achieved_target = target + away
    @assert (result == achieved_target) "Something went wrong: I thought I had $achieved_target, but I have $result instead."

    # TODO replace this with full blown readable output
    print("\n*** Make sense of \n$(solution)\n and it will give you $(result). ***\n")

    if (away != 0) 
        away = abs(away)
        print("$away away from $target.\n")
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

