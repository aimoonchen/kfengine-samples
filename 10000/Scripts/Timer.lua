local m = {
    cid = 0,
    timer = {}
}

function m:AddTimer(interval, func, repeat_count, delay, paused)
    local t = {
        current = delay and -delay or 0,
        count = 0,
        interval = interval,
        func = func,
        repeat_count = repeat_count,
        paused = paused
    }
    --fist time
    if t.current >= 0 then
        t.func()
        if t.repeat_count and t.repeat_count > 1 then
            t.count = t.count + 1
        end
    end
    self.cid = self.cid + 1
    self.timer[self.cid] = t
    return self.cid
end

function m:DelTimer(tid)
    self.timer[tid] = {}
end

function m:StartTimer(tid)
    self.timer[tid].paused = false
end

function m:Update(timeStep)
    for i, t in ipairs(self.timer) do
        if not t.paused then
            t.current = t.current + timeStep
            if t.current >= t.interval then
                t.func()
                if t.repeat_count and t.repeat_count > 1 then
                    t.count = t.count + 1
                    if t.count >= t.repeat_count then
                        self.timer[i] = {}
                    end
                end
                t.current = 0
            end
        end
    end
end

return m