# S&P500指数の値動きからSPXLを計算するためのデータを作成する
using CSV, DataFrames, Dates, Plots
pyplot(fmt=:svg, fontfamily="meiryo") # plotの設定

# 正解値SPXL読み込み
dfmt = dateformat"yyyy/mm/dd HH:MM:SS"
spxl = DataFrame(CSV.File("./data/SPXL_20210430.csv", dateformat=dfmt, header=true))
dt = spxl.timestamp .- Dates.Hour(14) # Yahooで取得をしたデータは日本時間なので，USに変換する
spxl.timestamp = dt

# S&P500のDividendYield(配当利回り)の読み込み--------------------------------
dfmt = dateformat"yyyy/mm/dd"
sp500_yield = DataFrame(CSV.File("./data/S&P500_DividendYield.csv", dateformat=dfmt, header=true))
sort!(sp500_yield) # 昇順にソートsort

# SPYのdividendsは四半期単位なので，サンプリングをSPXLに合わせて前値ホールドする
spy_dint = copy(spxl)
select!(spy_dint, Not(:open))
rename!(spy_dint, "low" => "yield") # その年の配当金利回り
rename!(spy_dint, "high" => "dtb3") # 米国3ヶ月債金利
rename!(spy_dint, "close" => "spxl") # SPXL価格
rename!(spy_dint, "volume" => "spxl_pred") # 予測SPXL

d_temp = 1
for y in 1:length(sp500_yield.yield)
    println("y = " * string(y))
    for d in d_temp:length(spy_dint.timestamp)
        # println("d = " * string(d))
        yield = sp500_yield[y,"yield"] # 配当利回りを取得
        spy_dint.yield[d] = yield # 次のyearに該当するまで，前値を当てはめる
        if (Dates.Date(spy_dint.timestamp[d]) > sp500_yield.date[y])
            d_temp = d
            break
        end
    end
end

# DTB3(金利)の読み込み--------------------------------
dfmt = dateformat"yyyy/mm/dd"
dtb3 = DataFrame(CSV.File("./data/DTB3.csv", dateformat=dfmt, header=true))
dfmt = dateformat"yyyy-mm-dd"
dt = [DateTime(x, dfmt) for x in dtb3[:,"DATE"]]
dtb3.timestamp = dt
select!(dtb3, Not(:DATE))

# 値を入れていく
for y in 1:length(spy_dint.timestamp)
    for d in 1:length(dtb3.timestamp)
        if (Date(spy_dint.timestamp[y]) == Date(dtb3.timestamp[d]))
            spy_dint.dtb3[y] = dtb3.DTB3[d]
            # println("d = " * string(d))
            break
        end
        spy_dint.dtb3[y] = NaN
    end
end
spy_dint = spy_dint[ .!(isnan.(spy_dint.dtb3)), :] # NaNのある行の削除

# S&P500の読み込み--------------------------------
dfmt = dateformat"yyyy/mm/dd HH:MM:SS"
sp500 = DataFrame(CSV.File("./data/S&P500.csv", dateformat=dfmt, header=true))
dt = sp500.timestamp .- Dates.Hour(14) # Yahooで取得をしたデータは日本時間なので，USに変換する
sp500.timestamp = dt
select!(sp500, Not(:open))
select!(sp500, Not(:low))
select!(sp500, Not(:high))
select!(sp500, Not(:volume))
rename!(sp500, "close" => "sp500") # SPY価格

spy_dint = innerjoin(spy_dint, sp500, on=:timestamp)

# 疑似SPXLを計算する元データを保存
CSV.write("./data/spxl_prediction_data.csv", spy_dint)

# 疑似SPXLを計算-----------------------------------------------
# 1. 単純計算が実際のSPXLより大きいことを確認
dif = (spy_dint.sp500[2:end] - spy_dint.sp500[1:end - 1]) # 1日の値動き幅
dif_rate = dif ./ spy_dint.sp500[1:end - 1] # 値動き割合
dif_rate_y = dif_rate + spy_dint.yield[1:end - 1] ./ 365 # 配当込み1日値動き割合
dif_rate3 = dif_rate_y * 3
spxl_pred1 = ones(length(spy_dint.sp500), 1) * 4.25
for i = 2:length(spxl_pred1)
    spxl_pred1[i] = spxl_pred1[i - 1] * dif_rate3[i - 1] + spxl_pred1[i - 1]
end

plot(spy_dint.timestamp, spy_dint.spxl, 
    xlabel="年月日", ylabel="価格[\$]", label="SPXL")
plot!(spy_dint.timestamp, spxl_pred1, label="SPXL(S&P500値動き3倍)")
savefig("SPXL_dif_rate3.png")

# 2. 0.95% 考慮でも実際のSPXLより大きいことを確認
dif_rate3_c095 = dif_rate3 .- (0.95 / 100 / 365) 
spxl_pred2 = ones(length(spy_dint.sp500), 1) * 4.25
for i = 2:length(spxl_pred2)
    spxl_pred2[i] = spxl_pred2[i - 1] * dif_rate3_c095[i - 1] + spxl_pred2[i - 1]
end

plot(spy_dint.timestamp, spy_dint.spxl, 
    xlabel="年月日", ylabel="価格[\$]", label="SPXL")
plot!(spy_dint.timestamp, spxl_pred2, label="SPXL(S&P500値動き3倍+コスト0.95%)")
savefig("SPXL_dif_rate3_c095.png")

spxl_err2 = (spxl_pred2 .- spy_dint.spxl) ./ spy_dint.spxl
plot(spy_dint.timestamp, spxl_err2,
    xlabel="年月日", ylabel="SPXL予測の乖離率",
    ylims=(-0.2, 0.4))
savefig("SPXL_dif_rate3_c095_err.png")

# 3. 計算式に割り当てる
dif_rate3_dtb3 = dif_rate3 - ( spy_dint.dtb3[1:end - 1] / 100 / 365 * 2) 
dif_rate3_dtb3_c215 = dif_rate3_dtb3 .- (2.15 / 100 / 365)
spxl_pred3 = ones(length(spy_dint.sp500), 1) * 4.25
for i = 2:length(spxl_pred3)
    spxl_pred3[i] = spxl_pred3[i - 1] * dif_rate3_dtb3_c215[i - 1] + spxl_pred3[i - 1]
end

plot(spy_dint.timestamp, spy_dint.spxl, 
    xlabel="年月日", ylabel="価格[\$]", label="SPXL")
plot!(spy_dint.timestamp, spxl_pred3, label="SPXL(S&P500値動き3倍+先物金利+コスト2.15%)")
savefig("SPXL_dif_rate3_dtb3_c215.png")

spxl_err3 = (spxl_pred3 .- spy_dint.spxl) ./ spy_dint.spxl
plot(spy_dint.timestamp, spxl_err3,
    xlabel="年月日", ylabel="SPXL予測の乖離率",
    ylims=(-0.2, 0.4))
savefig("SPXL_dif_rate3_dtb3_c215_err.png")

# 3.2 固定コストを上げる
dif_rate3_dtb3_c315 = dif_rate3_dtb3 .- (3.15 / 100 / 365)
spxl_pred4 = ones(length(spy_dint.sp500), 1) * 4.25
for i = 2:length(spxl_pred4)
    spxl_pred4[i] = spxl_pred4[i - 1] * dif_rate3_dtb3_c315[i - 1] + spxl_pred4[i - 1]
end

plot(spy_dint.timestamp, spy_dint.spxl, 
    xlabel="年月日", ylabel="価格[\$]", label="SPXL")
plot!(spy_dint.timestamp, spxl_pred4, label="SPXL(S&P500値動き3倍+先物金利+コスト3.15%)")
savefig("SPXL_dif_rate3_dtb3_c315.png")

spxl_err4 = (spxl_pred4 .- spy_dint.spxl) ./ spy_dint.spxl
plot(spy_dint.timestamp, spxl_err4,
    xlabel="年月日", ylabel="SPXL予測の乖離率",
    ylims=(-0.2, 0.4))
savefig("SPXL_dif_rate3_dtb3_c315_err.png")


# 1954以降の疑似SPXLとS&P 500を計算-----------------------------------------------
# SP500, SP500利回り，米国3ヶ月債金利を用意 
spxl_pred = sp500[sp500.timestamp.>Dates.Date("1954-1-4"), :]
spxl_pred.timestamp = Dates.Date.(spxl_pred.timestamp)
dtb3.timestamp = Dates.Date.(dtb3.timestamp)
spxl_pred = innerjoin(spxl_pred, dtb3, on=:timestamp)

spxl_pred.sp500_yield = ones(length(spxl_pred.timestamp))
d_temp = 1
for y in 1:length(sp500_yield.yield)
    println("y = " * string(y))
    for d in d_temp:length(spxl_pred.timestamp)
        # println("d = " * string(d))
        yield = sp500_yield[y,"yield"] # 配当利回りを取得
        spxl_pred.sp500_yield[d] = yield # 次のyearに該当するまで，前値を当てはめる
        if (Dates.Date(spxl_pred.timestamp[d]) > sp500_yield.date[y])
            d_temp = d
            break
        end
    end
end

# 1954年のSP500と同一金額からスタートした場合のSPXLを計算
spxl_pred.spxl = ones(length(spxl_pred.timestamp))*spxl_pred.sp500[1]

dif = (spxl_pred.sp500[2:end] - spxl_pred.sp500[1:end - 1]) # 1日の値動き幅
dif_rate = dif ./ spxl_pred.sp500[1:end - 1] # 値動き割合
dif_rate_y = dif_rate + spxl_pred.sp500_yield[1:end - 1] ./ 365 # 配当込み1日値動き割合
dif_rate3 = dif_rate_y * 3 # 配当込値動き割合の3倍
dif_rate3_dtb3 = dif_rate3 - ( spxl_pred.DTB3[1:end - 1] / 100 / 365 * 2) # 3ヶ月債の2倍の金利を引く
dif_rate3_dtb3_c315 = dif_rate3_dtb3 .- (3.15 / 100 / 365) # 固定コスト3.15%を上乗せ

for i = 2:length(spxl_pred.timestamp)
    spxl_pred.spxl[i] = spxl_pred.spxl[i - 1] * dif_rate3_dtb3_c315[i - 1] + spxl_pred.spxl[i - 1]
end

# 比較対象としてSP500の配当込み指数を計算．
spxl_pred.sp500_yidx = ones(length(spxl_pred.timestamp))*spxl_pred.sp500[1]
dif_rate_y_c = dif_rate_y .- (0.141 / 100 / 365) # 固定コスト0.141%を上乗せ

for i = 2:length(spxl_pred.timestamp)
    spxl_pred.sp500_yidx[i] = spxl_pred.sp500_yidx[i - 1] * dif_rate_y_c[i - 1] + spxl_pred.sp500_yidx[i - 1]
end

CSV.write("spxl_pred_1954.csv", spxl_pred)

# トータルリターンの計算
sp500_ret = spxl_pred.sp500_yidx[spxl_pred.timestamp.==Dates.Date("2020-7-1")]/spxl_pred.sp500_yidx[spxl_pred.timestamp.==Dates.Date("1954-7-1")]
spxl_ret = spxl_pred.spxl[spxl_pred.timestamp.==Dates.Date("2020-7-1")]/spxl_pred.spxl[spxl_pred.timestamp.==Dates.Date("1954-7-1")]


plot(spxl_pred.timestamp, spxl_pred.sp500_yidx, 
    xlabel="年月日", ylabel="価格[\$]", label="仮想インデックス(S&P500配当込み指数+コスト0.141%)", yscale=:log10)
plot!(spxl_pred.timestamp, spxl_pred.spxl, label="仮想SPXL(S&P500値動き3倍+先物金利+コスト3.15%)", yscale=:log10)
savefig("SP500_SPXL_1954.png")
