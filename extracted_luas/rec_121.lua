function Debug(msg)
    game:Reportv(1,"[lua]"..msg)
end

function Info(msg)
    game:Reportv(10,"[lua]"..msg)
end

function Warn(msg)
    game:Reportv(50,"[lua]"..msg)
end

function Error(msg)
    game:Reportv(100,"[lua]"..msg)
end