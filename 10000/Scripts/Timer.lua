local m = {
    cid = 0,
    timer = {}
}

function m:AddTimer(interval, func, repeat_count, delay, paused)
    local t = {
        current = 0,
        count = 0,
        interval = interval,
        func = func,
        repeat_count = repeat_count,
        paused = paused,
        delay = delay
    }
    if t.delay > 0 then
        t.paused = true
    elseif not t.paused then
        --fist time
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

function m:DoCall(tid)
    local t = self.timer[tid]
    t.func()
    if t.repeat_count and t.repeat_count > 1 then
        t.count = t.count + 1
        if t.count >= t.repeat_count then
            self.timer[tid] = {}
        end
    end
end

function m:Update(timeStep)
    for i, t in ipairs(self.timer) do
        if not t.paused then
            t.current = t.current + timeStep
            if t.current >= t.interval then
                t.current = t.current - t.interval
                self:DoCall(i)
            end
        elseif t.delay and t.delay > 0 then
            t.delay = t.delay - timeStep
            if t.delay <= 0 then
                t.paused = false
                self:DoCall(i)
            end
        end
    end
end

return m