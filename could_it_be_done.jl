
# (Written for Julia 0.6.0)

function could_it_be_done(target::UInt16, numbers::Array{UInt8, 1})
    # "An electronic computer called CECIL selects a target number from 101 to 999 inclusive at random."
    # (http://www.ukgameshows.com/ukgs/Countdown)
    if !(101 <= target <= 999)
        error("Are you trying to have a go at me, mate? The target should be between 101 and 999, not $(target).")
    end

    solution = find_arithmetic_expr(target, numbers)

    # if target is not doable, try to get the closest valid number that is doable
    away = 0
    while (solution == nothing) && (-10 <= away <= 10)
        # TODO additional msg in output to indicate target was not achievable, etc.
        away = (away <= 0) ? (-away + 1) : (-away) # Go 1 to -1 to 2 to -2 to 3 to ...
        nearby_target = UInt16(target + away)
        solution = find_arithmetic_expr(nearby_target, numbers)
    end

    tell_them(solution)
end

#=
find_arithmetic_expr(target, numbers) -> Expr

Given a target number and an array of initial numbers to work with, figures out
an arithmetic expression that uses the initial numbers to create the final number.

Note: 
Number of potential expressions given n numbers and 4 binary operations 
(excluding when target is one of the numbers) 
 = nC2 * 4 + nC3 * 4 * 4 + ... + nCn * (4)^(n-1)
 = sum( nCk * (4)^(k-1) ) for k = 2 to n
 = sum_(k=2)^n 4^(k - 1) binomial(n, k) = 1/4 (-4 n + 5^n - 1) #Wolfram Alpha
which for n = 6 comes to just 3900. So, even just brute forcing through 
evaluating 3900 expressions would be doable. 

=#
function find_arithmetic_expr(target::UInt16, numbers::Array{UInt8, 1})::Union{Expr,Void}
    if target in numbers
        #return it raised to power one so it remains Expr and doesn't autoreduce to Int
        return :($target ^ 1) 
    end

    solution = nothing

    #= Try to simplify the target by looking for factors among the numbers =#
    array_rem_idx(arr, idx) = (arr[[1:(idx-1); (idx+1):length(arr)]])
    for idx in eachindex(numbers)
        n = numbers[idx]
        print("n is $(n) and target is $(target)\n")
        if target % n == 0 
            unused_nums = array_rem_idx(numbers, idx)
            partial_soln = find_arithmetic_expr(div(target, n), unused_nums)
            if partial_soln != nothing
                solution = :($n * $partial_soln)
                break
            end
        end
    end

    for idx in eachindex(numbers)
        subset = [numbers[idx]]
    end

    return solution
end

function tell_them(solution::Union{Expr, Void})
    if solution == nothing
        print("This one is impossible. Sorry!\n")
        return
    end

    #= print("You could have said:\n")
    if length(solution) == 1 && solution[1] isa UInt8
        print("You've already got a $(solution[1]), no hard work!\n")
        return
    end
    =#

    print("Uhh something with $(solution) I guess.")
end

