local m = {

}

function m.MultiRandom(min, max, count)
    local function unique_random(t, from, to)
        local num = math.random(from, to)
        if t[num] then
            num = unique_random(t, from, to)
        end
        t[num] = num
        return num
     end
    local r = {}
    local h = {}
    for i = 1, count do
        r[i] = unique_random(h, min, max)
    end
    return r
end

return m