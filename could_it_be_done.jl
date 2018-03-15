
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

"""
find_arithmetic_expr(target, numbers) -> Expr

Given a target number and an array of initial numbers to work with, figures out
an arithmetic expression that uses the initial numbers to create the final number.

The initial numbers are UInt16 here though the original numbers in the game 
are UInt8, because the intermediate targets are also calculated using this
function (recursively), and those can be above 255. 


"""
function find_arithmetic_expr(target::UInt16, numbers::Array{UInt16, 1})
    if target in numbers
        return :($target)
    end

    solution = nothing
    for idx in eachindex(numbers)
        n = numbers[idx]
        print("n is $(n) and target is $(target)\n")
        if target % n == 0 
            ununsed_nums = numbers[[1:(idx-1); (idx+1):length(numbers)]]
            partial_soln = find_arithmetic_expr(div(target, n), ununsed_nums)
            if partial_soln != nothing
                solution = :($n * $partial_soln)
            end
        end
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

