local m = {
    timers = {}
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
    if t.delay and t.delay > 0 then
        t.paused = true
    elseif not t.paused then
        --fist time
        t.func()
        if t.repeat_count and t.repeat_count > 1 then
            t.count = t.count + 1
        end
    end
    self.timers[#self.timers + 1] = t
    return t
end

function m:DelTimer(t)
    for i = #self.timers, 1, -1 do
        if self.timers[i] == t then
          table.remove(self.timers, i)
          break
        end
    end
end

function m:Clean()
    self.timers = {}
end

function m:StartTimer(tid)
    self.timers[tid].paused = false
end

function m:DoCall(idx)
    local t = self.timers[idx]
    t.func()
    if t.repeat_count and t.repeat_count > 1 then
        t.count = t.count + 1
        if t.count >= t.repeat_count then
            table.remove(self.timers, idx)
        end
    end
end

function m:Update(timeStep)
    for i = #self.timers, 1, -1 do
        local t = self.timers[i]
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