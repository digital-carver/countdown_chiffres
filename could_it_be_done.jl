
# (Written for Julia 0.6.0)

function could_it_be_done(target::UInt16, numbers::Array{UInt8, 1})
    # "An electronic computer called CECIL selects a target number from 101 to 999 inclusive at random."
    # (http://www.ukgameshows.com/ukgs/Countdown)
    if !(101 <= target <= 999)
        error("Are you trying to have a go at me, mate? The target should be between 101 and 999, not $(target).")
    end

    solution = find_arithmetic_expr(target, numbers)

    away = 0
    while (solution == nothing) && (-10 <= away <= 10)
        away = (away <= 0) ? (-away + 1) : (-away) # Go 1 to -1 to 2 to -2 to 3 to ...
        print(away)
        nearby_target = UInt16(target + away)
        solution = find_arithmetic_expr(nearby_target, numbers)
    end

    tell_them(solution)
end

function find_arithmetic_expr(target::UInt16, numbers::Array{UInt8, 1})
    if length(numbers) == 1
        if target == numbers[1]
            return numbers
        end
    end
    return nothing
end

function tell_them(solution::Union{Array, Void})
    if solution == nothing
        print("This one is impossible. Sorry!\n")
    end

    print("You could have said:\n")
    if length(solution) == 1 && solution[1] isa UInt8
        print("You've already got a $(solution[1]), no hard work!\n")
    end

end

