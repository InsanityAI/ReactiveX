if Debug then Debug.beginFile "ReactiveX/Util" end
OnInit.module("ReactiveX.Util", function(require)
    if Debug then Debug.log("Test") end
    ReactiveXUtil = {}
    ReactiveXUtil.pack = table.pack or function(...) return { n = select('#', ...), ... } end
    ---@diagnostic disable-next-line: deprecated
    ReactiveXUtil.unpack = table.unpack or unpack
    ReactiveXUtil.eq = function(x, y) return x == y end
    ReactiveXUtil.noop = function() end
    ReactiveXUtil.identity = function(x) return x end
    ReactiveXUtil.constant = function(x) return function() return x end end
    ReactiveXUtil.isa = function(object, class)
        return type(object) == 'table' and getmetatable(object).__index == class
    end
    ReactiveXUtil.tryWithObserver = function(observer, fn, ...)
        local success, result = pcall(fn, ...)
        if not success then
            observer:onError(result)
        end
        return success, result
    end

    if Debug then Debug.log("Test end") end
    return ReactiveXUtil
end)
if Debug then Debug.endFile() end