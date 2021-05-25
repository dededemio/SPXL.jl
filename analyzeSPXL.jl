# SPXL長期模擬データから，運用ケース別の成績を計算する
using CSV, DataFrames, Dates, Plots, StatsBase
pyplot(fmt=:svg, fontfamily="meiryo") # plotの設定

# SPXL読み込み
dfmt = dateformat"yyyy-mm-dd"
spxl = DataFrame(CSV.File("./spxl_pred_1954.csv", dateformat=dfmt, header=true))

# -------------------------------------
# (1)まずはSP500とSPXLで，30年の運用データの中央値，上位下位5%の価格推移を計算する
# -------------------------------------
# SPXLを30年データに分割
# 1954/1/4~1984/1/4, 1954/1/5~1984/1/5...1981/4/28~2021/4/28というイメージ
st_date = spxl.timestamp[1]
data_len = length(spxl.timestamp[spxl.timestamp .<= st_date + Dates.Year(30)])
en_date = spxl.timestamp[data_len]
# データ数data_len(7541日)分のデータを，data_num(9407)個用意
data_num = length(spxl.spxl) - data_len + 1
spxl_30y = ones(data_len, data_num)
for i in 1:data_num
    spxl_30y[:,i] = spxl.spxl[i:i + data_len - 1]
end

# データの正規化(1行目の値を1とした比率に変換)
for c = 1:data_num
    spxl_30y[:,c] ./= spxl_30y[1,c]
end

# 5パーセンタイル，50パーセンタイル, 95パーセンタイルを計算してプロット
quan_spxl = zeros(data_len, 3)
for r in 1:data_len
    quan_spxl[r,:] = quantile(spxl_30y[r,:], [0.05, 0.5, 0.95])
end

labels = ["下位5%", "中央値", "上位5%", "投資額"]
plot( (1:data_len) .* 30 / data_len, quan_spxl[:,3], label=labels[3], linecolor=:blue, xlabel="年", ylabel="価格[\$]", yscale=:log10, ylims=(10^-0.5, 10^2.5))
plot!( (1:data_len) .* 30 / data_len, quan_spxl[:,2], label=labels[2], linecolor=:green, ms=1, yscale=:log10)
plot!( (1:data_len) .* 30 / data_len, quan_spxl[:,1], label=labels[1], linecolor=:red, yscale=:log10)
savefig("SPXL_30y_5parcentile.png")


# sp500を30年データに分割--------------------
sp500_30y = ones(data_len, data_num)
for i in 1:data_num
    sp500_30y[:,i] = spxl.sp500_yidx[i:i + data_len - 1]
end

# データの正規化(1行目の値を1とした比率に変換)
for c = 1:data_num
    sp500_30y[:,c] ./= sp500_30y[1,c]
end

# 5パーセンタイル，50パーセンタイル, 95パーセンタイルを計算してプロット
quan_sp500 = zeros(data_len, 3)
for r in 1:data_len
    quan_sp500[r,:] = quantile(sp500_30y[r,:], [0.05, 0.5, 0.95])
end

plot( (1:data_len) .* 30 / data_len, quan_sp500[:,3], label=labels[3], linecolor=:blue, xlabel="年", ylabel="価格[\$]", yscale=:log10, ylims=(10^-0.5, 10^2.5))
plot!( (1:data_len) .* 30 / data_len, quan_sp500[:,2], label=labels[2], linecolor=:green, yscale=:log10)
plot!( (1:data_len) .* 30 / data_len, quan_sp500[:,1], label=labels[1], linecolor=:red, yscale=:log10)
savefig("SP500_30y_5parcentile.png")

# -------------------------------------
# (2)上記の価格推移で，500万+毎月10万を積立投資した場合を計算する
# -------------------------------------

# 年月日から購入金額を計算
purchases = zeros(data_len)
purchases[1] = 500 # 初回500万円
mid_flag = false
for i = 2:data_len
    if (Dates.Month(spxl.timestamp[i - 1]) != Dates.Month(spxl.timestamp[i]))
        purchases[i] = 10
        mid_flag = false
    elseif ( (Dates.Month(spxl.timestamp[i]) == Dates.Month(6) || Dates.Month(spxl.timestamp[i]) == Dates.Month(12)) && 
        Dates.Day(spxl.timestamp[i]) > Dates.Day(15) && mid_flag == false)
        purchases[i] = 20
        mid_flag = true
    end
end

# 購入金額を積算して，総投資額も計算しておく
total_purchases = accumulate(+, purchases)

# 購入株式数
quantity_spxl = zeros(size(spxl_30y))
for n in 1:data_num
    quantity_spxl[:,n] = purchases ./ spxl_30y[:,n]
end

# 購入株式数を積算して保有株式数とする
stocks_spxl = zeros(size(spxl_30y)) 
for n in 1:data_num
    stocks_spxl[:,n] = accumulate(+, quantity_spxl[:,n])
end

# 保有株式数にその時の価格を掛け算して，資産額を算出
assets_spxl = copy(stocks_spxl)
for c = 1:data_num
    assets_spxl[:,c] .*= spxl_30y[:,c]
end

# 5パーセンタイル，50パーセンタイル, 95パーセンタイルを計算してプロット
quan_spxl_assets = zeros(data_len, 3)
for r in 1:data_len
    quan_spxl_assets[r,:] = quantile(assets_spxl[r,:], [0.05, 0.5, 0.95])
end

plot( (1:data_len) .* 30 / data_len, quan_spxl_assets[:,3], label=labels[3], linecolor=:blue, xlabel="年", ylabel="資産額[万円]", yscale=:log10, ylims=(10^2.5, 10^6.0))
plot!( (1:data_len) .* 30 / data_len, quan_spxl_assets[:,2], label=labels[2], linecolor=:green, yscale=:log10)
plot!( (1:data_len) .* 30 / data_len, quan_spxl_assets[:,1], label=labels[1], linecolor=:red, yscale=:log10)
plot!( (1:data_len) .* 30 / data_len, total_purchases, label=labels[4], linecolor=:black, yscale=:log10)
savefig("SPXL_30y_5parcentile_assets.png")

# 成績の計算
for i = 3:-1:1
    print(labels[i] * ": " * string(quan_spxl_assets[end, i] * (1 - 0.20315)) * "万円\n")
end
quan_spxl_assets[2513, 2]

print("下位5%の最大下落率[%]:" * string(100 - minimum(quan_spxl_assets[:,1] ./ total_purchases) * 100)[1:4])


# SP500も計算-------------------------
# 購入株式数
quantity_sp500 = zeros(size(sp500_30y))
for n in 1:data_num
    quantity_sp500[:,n] = purchases ./ sp500_30y[:,n]
end

# 購入株式数を積算して保有株式数とする
stocks_sp500 = zeros(size(sp500_30y)) 
for n in 1:data_num
    stocks_sp500[:,n] = accumulate(+, quantity_sp500[:,n])
end

# 保有株式数にその時の価格を掛け算して，資産額を算出
assets_sp500 = copy(stocks_sp500)
for c = 1:data_num
    assets_sp500[:,c] .*= sp500_30y[:,c]
end

# 5パーセンタイル，50パーセンタイル, 95パーセンタイルを計算してプロット
quan_sp500_assets = zeros(data_len, 3)
for r in 1:data_len
    quan_sp500_assets[r,:] = quantile(assets_sp500[r,:], [0.05, 0.5, 0.95])
end

plot( (1:data_len) .* 30 / data_len, quan_sp500_assets[:,3], label=labels[3], linecolor=:blue, xlabel="年", ylabel="資産額[万円]", yscale=:log10, ylims=(10^2.5, 10^6.0))
plot!( (1:data_len) .* 30 / data_len, quan_sp500_assets[:,2], label=labels[2], linecolor=:green, yscale=:log10)
plot!( (1:data_len) .* 30 / data_len, quan_sp500_assets[:,1], label=labels[1], linecolor=:red, yscale=:log10)
plot!( (1:data_len) .* 30 / data_len, total_purchases, label=labels[4], linecolor=:black, yscale=:log10)
savefig("SP500_30y_5parcentile_assets.png")
# 成績の計算
for i = 3:-1:1
    print(labels[i] * ": " * string(quan_sp500_assets[end, i] * (1 - 0.20315))[1:6] * "万円\n")
end
quan_sp500_assets[2513, 2] # 10年時点の中央値

print("下位5%の最大下落率[%]:" * string(100 - minimum(quan_sp500_assets[:,1] ./ total_purchases) * 100)[1:4])


# -------------------------------------
# (3)運用パターン変更(完全積立投資)
# -------------------------------------
# 5300万を全て積立投資する．30*12=360ヶ月あるので，14.7万円ずつ．

# 年月日から購入金額を計算
purchases = zeros(data_len)
amount = (5300 / 360)
purchases[1] = amount # 初回
for i = 2:data_len
    if (Dates.Month(spxl.timestamp[i - 1]) != Dates.Month(spxl.timestamp[i])) # 月が変わったタイミングで投資
        purchases[i] = amount
    end
end

# 購入金額を積算して，総投資額も計算しておく
total_purchases = accumulate(+, purchases)

# 購入株式数
quantity_spxl = zeros(size(spxl_30y))
for n in 1:data_num
    quantity_spxl[:,n] = purchases ./ spxl_30y[:,n]
end

# 購入株式数を積算して保有株式数とする
stocks_spxl = zeros(size(spxl_30y)) 
for n in 1:data_num
    stocks_spxl[:,n] = accumulate(+, quantity_spxl[:,n])
end

# 保有株式数にその時の価格を掛け算して，資産額を算出
assets_spxl = copy(stocks_spxl)
for c = 1:data_num
    assets_spxl[:,c] .*= spxl_30y[:,c]
end

# 5パーセンタイル，50パーセンタイル, 95パーセンタイルを計算してプロット
quan_spxl_assets = zeros(data_len, 3)
for r in 1:data_len
    quan_spxl_assets[r,:] = quantile(assets_spxl[r,:], [0.05, 0.5, 0.95])
end

plot( (1:data_len) .* 30 / data_len, quan_spxl_assets[:,3], label=labels[3], linecolor=:blue, xlabel="年", ylabel="資産額[万円]", yscale=:log10)
plot!( (1:data_len) .* 30 / data_len, quan_spxl_assets[:,2], label=labels[2], linecolor=:green, yscale=:log10)
plot!( (1:data_len) .* 30 / data_len, quan_spxl_assets[:,1], label=labels[1], linecolor=:red, yscale=:log10)
plot!( (1:data_len) .* 30 / data_len, total_purchases, label=labels[4], linecolor=:black, yscale=:log10)
savefig("SPXL_30y_5parcentile_assets_積立時.png")

# 成績の計算
for i = 3:-1:1
    print(labels[i] * ": " * string(quan_spxl_assets[end, i] * (1 - 0.20315))[1:7] * "万円\n")
end
quan_spxl_assets[2513, 2] # 10年時点の中央値

print("下位5%の最大下落率[%]:" * string(100 - minimum(quan_spxl_assets[:,1] ./ total_purchases) * 100)[1:4])

# SP500も計算-------------------------
# 購入株式数
quantity_sp500 = zeros(size(sp500_30y))
for n in 1:data_num
    quantity_sp500[:,n] = purchases ./ sp500_30y[:,n]
end

# 購入株式数を積算して保有株式数とする
stocks_sp500 = zeros(size(sp500_30y)) 
for n in 1:data_num
    stocks_sp500[:,n] = accumulate(+, quantity_sp500[:,n])
end

# 保有株式数にその時の価格を掛け算して，資産額を算出
assets_sp500 = copy(stocks_sp500)
for c = 1:data_num
    assets_sp500[:,c] .*= sp500_30y[:,c]
end

# 5パーセンタイル，50パーセンタイル, 95パーセンタイルを計算してプロット
quan_sp500_assets = zeros(data_len, 3)
for r in 1:data_len
    quan_sp500_assets[r,:] = quantile(assets_sp500[r,:], [0.05, 0.5, 0.95])
end

plot( (1:data_len) .* 30 / data_len, quan_sp500_assets[:,3], label=labels[3], linecolor=:blue, xlabel="年", ylabel="資産額[万円]", yscale=:log10)
plot!( (1:data_len) .* 30 / data_len, quan_sp500_assets[:,2], label=labels[2], linecolor=:green, yscale=:log10)
plot!( (1:data_len) .* 30 / data_len, quan_sp500_assets[:,1], label=labels[1], linecolor=:red, yscale=:log10)
plot!( (1:data_len) .* 30 / data_len, total_purchases, label=labels[4], linecolor=:black, yscale=:log10)
savefig("SP500_30y_5parcentile_assets_積立時.png")

# 成績の計算
for i = 3:-1:1
    print(labels[i] * ": " * string(quan_sp500_assets[end, i] * (1 - 0.20315))[1:7] * "万円\n")
end
quan_sp500_assets[2513, 2] # 10年時点の中央値

print("下位5%の最大下落率[%]:" * string(100 - minimum(quan_sp500_assets[:,1] ./ total_purchases) * 100)[1:4])


# -------------------------------------
# (4)現金-SPXLリバランス
# -------------------------------------
# 最初に500万円投資，30年間現金は保有，50:50 or 70:30で毎月頭にリバランス
# ただし，平均購入金額を下回ったら売却はしない．

# 年月日から投資への現金追加額を計算
purchases = zeros(data_len)
purchases[1] = 500 # 初回500万円
mid_flag = false
for i = 2:data_len
    if (Dates.Month(spxl.timestamp[i - 1]) != Dates.Month(spxl.timestamp[i]))
        purchases[i] = 10
        mid_flag = false
    elseif ( (Dates.Month(spxl.timestamp[i]) == Dates.Month(6) || Dates.Month(spxl.timestamp[i]) == Dates.Month(12)) && 
        Dates.Day(spxl.timestamp[i]) > Dates.Day(15) && mid_flag == false)
        purchases[i] = 20
        mid_flag = true
    end
end
# 購入金額を積算して，総投資額も計算しておく
total_purchases = accumulate(+, purchases)

# リバランス計算を関数化
# price: 株価推移
# ratio: spxl対現金をいくつにするか．0.7なら70:30
# purchases: 追加投資現金
function rebalance(prices, ratio, purchases, timestamp, fee)
    # for debug
    # prices = spxl_30y[:,1]
    # ratio = 0.7
    # timestamp = spxl.timestamp
    # fee = 0.45/100
    # 変数定義と初期化
    tax_rate = 20.315 / 100 # 税率
    ave_unit_price = prices[1] # 平均取得単価
    hold_stock = zeros(length(prices)) # 保有株式数推移
    hold_stock[1] = purchases[1] * ratio / prices[1]
    hold_cash = zeros(length(prices)) # 保有現金推移
    hold_cash[1] = purchases[1] * (1 - ratio)
    ratio_temp = zeros(length(prices)) # リバランス時の比率
    ratio_temp[1] = ratio
    # 2日目以降を計算
    for i in 2:length(prices)
        # 現金を追加
        hold_cash[i] = purchases[i]
        # 月初めにリバランス
        if (Dates.Month(timestamp[i - 1]) != Dates.Month(timestamp[i]))
            # 現金と株式の比率を計算
            hold_stock_price = sum(hold_stock) * prices[i] # 現在の株式評価額
            hold_cash_price = sum(hold_cash) # 手持ちの現金
            # ratio_temp[i] = hold_stock_price / (hold_cash_price + hold_stock_price) # 現状の株式：現金比率
            diff = ratio * (hold_cash_price + hold_stock_price) - hold_stock_price # 理想の株式価格までの差額
            # 差額が正なら追加投資
            if (diff > 0) 
                hold_stock[i] += diff / prices[i] # 差額分の数量の株を追加購入
                hold_cash[i] -= diff * (1 + fee) # 購入+手数料分の現金を引く
                ave_unit_price = ( (sum(hold_stock[1:i - 1]) * ave_unit_price) + diff ) / sum(hold_stock) # 平均取得単価の更新
                # print(ave_unit_price)
                # print("\n")
            # 差額が負なら売却
            else
                # 株価が平均取得単価以上のときだけ売却．下回っていたらホールド．税金がかかるので，その分考慮して多めに売却する
                if (prices[i] >= ave_unit_price)
                    sale = -diff # 売却額
                    profit = sale - sale / prices[i] * ave_unit_price 
                    tax = profit * tax_rate # 税金
                    hold_stock[i] -= sale / prices[i] # 差額分の数量の株を売却
                    hold_cash[i] += sale * (1 - fee) - tax # 売却分(税額・手数料考慮)の現金を追加
                end
            end
            # 現金と株式の比率を計算
            hold_stock_price = sum(hold_stock) * prices[i] # 現在の株式評価額
            hold_cash_price = sum(hold_cash) # 手持ちの現金
            ratio_temp[i] = hold_stock_price / (hold_cash_price + hold_stock_price) # 現状の株式：現金比率
        end
    end

    return (hold_stock, hold_cash)
end

hold_stocks = zeros(size(spxl_30y))
hold_cash = zeros(size(spxl_30y))
for n in 1:data_num
    prices = spxl_30y[:,n]
    ratio = 0.7
    timestamp = spxl.timestamp
    fee = 0.45 / 100 
    (stock, cash) = rebalance(prices, ratio, purchases, timestamp, fee)
    hold_stocks[:,n] = stock
    hold_cash[:,n] = cash
end

# 購入株式数を積算して保有株式数とする
stocks_spxl = zeros(size(spxl_30y)) 
for n in 1:data_num
    stocks_spxl[:,n] = accumulate(+, hold_stocks[:,n])
end

# 保有株式数にその時の価格を掛け算して，資産額を算出
assets_spxl = copy(stocks_spxl)
for c = 1:data_num
    assets_spxl[:,c] .*= spxl_30y[:,c]
end

# 現金も積算する
total_cash = zeros(size(spxl_30y)) 
for n in 1:data_num
    total_cash[:,n] = accumulate(+, hold_cash[:,n])
end

# 5パーセンタイル，50パーセンタイル, 95パーセンタイルを計算してプロット
quan_assets = zeros(data_len, 3)
for r in 1:data_len
    quan_assets[r,:] = quantile(assets_spxl[r,:], [0.05, 0.5, 0.95])
end
quan_cash = zeros(data_len, 3)
for r in 1:data_len
    quan_cash[r,:] = quantile(total_cash[r,:], [0.05, 0.5, 0.95])
end


plot( (1:data_len) .* 30 / data_len, quan_assets[:,3], label="金融資産額" * labels[3], linecolor=:blue, xlabel="年", ylabel="資産額[万円]", yscale=:log10)
plot!( (1:data_len) .* 30 / data_len, quan_assets[:,2], label="金融資産額" * labels[2], linecolor=:green)
plot!( (1:data_len) .* 30 / data_len, quan_assets[:,1], label="金融資産額" * labels[1], linecolor=:red)
plot!( (1:data_len) .* 30 / data_len, quan_cash[:,3], label="現金" * labels[3], linestyle=:dot, linecolor=:blue)
plot!( (1:data_len) .* 30 / data_len, quan_cash[:,2], label="現金" * labels[2], linestyle=:dot, linecolor=:green)
plot!( (1:data_len) .* 30 / data_len, quan_cash[:,1], label="現金" * labels[1], linestyle=:dot, linecolor=:red)
plot!( (1:data_len) .* 30 / data_len, quan_assets[:,3] .+ quan_cash[:,3], label="合計" * labels[3], linestyle=:dash, linecolor=:blue)
plot!( (1:data_len) .* 30 / data_len, quan_assets[:,2] .+ quan_cash[:,2], label="合計" * labels[2], linestyle=:dash, linecolor=:green)
plot!( (1:data_len) .* 30 / data_len, quan_assets[:,1] .+ quan_cash[:,1], label="合計" * labels[1], linestyle=:dash, linecolor=:red)
plot!( (1:data_len) .* 30 / data_len, total_purchases, label=labels[4], linecolor=:black)
savefig("SPXL_30y_5parcentile_assets_70_30リバランス時.png")

# 成績の計算
for i = 3:-1:1
    print(labels[i] * ": " * string((quan_assets[end, i] * (1 - 0.20315) + quan_cash[end,i]))[1:7] * "万円\n")
end
quan_assets[2513, 2] + quan_cash[2513, 2] # 10年時点の中央値

print("下位5%の最大下落率[%]:" * string(100 - minimum((quan_assets[:,1] .+ quan_cash[:,1]) ./ total_purchases) * 100)[1:4])
    


# -------------------------------------
# (5)15年かけて購入，15年かけて売却
# -------------------------------------
# 年月日から購入金額を計算
data_len_2 = Int(floor(data_len / 2))
purchases = zeros(data_len)
amount = (5300 / (15 * 12))
purchases[1] = amount # 初回も同額
# 15年目まで購入
for i = 2:data_len_2
    if (Dates.Month(spxl.timestamp[i - 1]) != Dates.Month(spxl.timestamp[i])) # 月が変わったタイミングで投資
        purchases[i] = amount
    end
end

# 購入金額を積算して，総投資額も計算しておく
total_purchases = accumulate(+, purchases)

# 購入株式数を購入金額から計算
buy_spxl = zeros(size(spxl_30y))
for n in 1:data_num
    buy_spxl[:,n] = purchases ./ spxl_30y[:,n]
end

# 売却株式数(きっかり15年で同量の株を売却する)
sale_spxl = zeros(size(spxl_30y))
for n in 1:data_num
    sale_spxl[data_len_2:data_len_2 * 2 - 1,n] = buy_spxl[1:data_len_2,n]
end

# 購入株式数と売却株式数を積算して保有株式数を計算する
total_holdings = copy(buy_spxl)
for c = 1:data_num
    total_buy = accumulate(+, buy_spxl[:,c]) # 購入株式数の積算
    total_sale = accumulate(+, sale_spxl[:,c]) # 売却株式数の積算
    total_holdings[:,c] = total_buy .- total_sale # 保有株式数
end
# 保有株式数にその時の価格を掛け算して，金融資産額を計算
holdings_price = copy(total_holdings)
for c = 1:data_num
    holdings_price[:,c] .*= spxl_30y[:,c]
end

# 売却株式数にその時の価格を掛け算して，売却金額を算出
sale_price_spxl = copy(sale_spxl)
for c = 1:data_num
    sale_price_spxl[:,c] .*= spxl_30y[:,c]
end

# 売却額を積算して現金保有額を計算
cash_spxl = zeros(size(spxl_30y)) 
for n in 1:data_num
    cash_spxl[:,n] = accumulate(+, sale_price_spxl[:,n])
end

# 5パーセンタイル，50パーセンタイル, 95パーセンタイルを計算してプロット
quan_spxl_holdings = zeros(data_len, 3)
for r in 1:data_len
    quan_spxl_holdings[r,:] = quantile(holdings_price[r,:], [0.05, 0.5, 0.95])
end
quan_spxl_cash = zeros(data_len, 3)
for r in 1:data_len
    quan_spxl_cash[r,:] = quantile(cash_spxl[r,:], [0.05, 0.5, 0.95])
end

# 対数グラフだと0が表示できないので，値を微妙に補正
quan_spxl_holdings .+= 10
quan_spxl_cash .+= 10

plot( (1:data_len) .* 30 / data_len, quan_spxl_holdings[:,3], label="金融資産額" * labels[3], linecolor=:blue, xlabel="年", ylabel="資産額[万円]", yscale=:log10)
plot!( (1:data_len) .* 30 / data_len, quan_spxl_holdings[:,2], label="金融資産額" * labels[2], linecolor=:green)
plot!( (1:data_len) .* 30 / data_len, quan_spxl_holdings[:,1], label="金融資産額" * labels[1], linecolor=:red)
plot!( (1:data_len) .* 30 / data_len, quan_spxl_cash[:,3], label="売却合計額" * labels[3], linestyle=:dot, linecolor=:blue)
plot!( (1:data_len) .* 30 / data_len, quan_spxl_cash[:,2], label="売却合計額" * labels[2], linestyle=:dot, linecolor=:green)
plot!( (1:data_len) .* 30 / data_len, quan_spxl_cash[:,1], label="売却合計額" * labels[1], linestyle=:dot, linecolor=:red)
plot!( (1:data_len) .* 30 / data_len, total_purchases, label=labels[4], linecolor=:black)
savefig("SPXL_30y_5parcentile_assets_15年積立15年売却時.png")

# 成績の計算
for i = 3:-1:1
    print(labels[i] * ": " * string(quan_spxl_cash[end, i] * (1 - 0.20315) / total_purchases[end])[1:4] * "倍\n")
end
print("下位5%の最大下落率[%]:" * string(100 - minimum((quan_spxl_holdings[:,1] ./ total_purchases)[1:data_len_2]) * 100)[1:4])


# -------------------------------------
# (6)タイミング投資(直近高値より10%下落で購入)
# -------------------------------------
# 最初に200万円投資，残り300万あり．毎月10万＋ボーナス月は＋20万追加．
# 直近高値に対して10%を下回っていた場合，下落幅に対して以下の式で追加投資を毎日する．
# ((下落率-8)^1.1)+12)*0.2[万円]

# 年月日から投資への現金追加額を計算
purchases = zeros(data_len)
purchases[1] = 500 # 初回500万円
mid_flag = false
for i = 2:data_len
    if (Dates.Month(spxl.timestamp[i - 1]) != Dates.Month(spxl.timestamp[i]))
        purchases[i] = 10
        mid_flag = false
    elseif ( (Dates.Month(spxl.timestamp[i]) == Dates.Month(6) || Dates.Month(spxl.timestamp[i]) == Dates.Month(12)) && 
        Dates.Day(spxl.timestamp[i]) > Dates.Day(15) && mid_flag == false)
        purchases[i] = 20
        mid_flag = true
    end
end
# 購入金額を積算して，総投資額も計算しておく
total_purchases = accumulate(+, purchases)

# ナンピン投資を関数化
# price: 株価推移
# purchases: 追加投資現金
function additional(prices, purchases, timestamp, fee)
    # for debug
    # prices = spxl_30y[:,1]
    # timestamp = spxl.timestamp
    # fee = 0.45/100

    # 変数定義と初期化
    recent_high_price = prices[1] # 直近高値
    hold_stock = zeros(length(prices)) # 保有株式数推移
    hold_stock[1] = purchases[1] * 2.0 / 5.0 / prices[1]
    hold_cash = zeros(length(prices)) # 保有現金推移
    hold_cash[1] = purchases[1] * 3.0 / 5.0
    decrease_rate_total = zeros(length(prices)) # 下落幅

    # 2日目以降を計算
    for i in 2:length(prices)
        # 保有現金を更新
        hold_cash[i] = hold_cash[i - 1] + purchases[i]
        # 直近高値を更新=直近1ヶ月の最高値
        recent = 10
        if (i <= recent)
            recent_high_price = maximum(prices[1:i])
        else
            recent_high_price = maximum(prices[i - recent:i])
        end

        if (hold_cash[i] > 0)
            # 高値から10%を下回っていたら
            decrease_rate = 100.0 - prices[i] / recent_high_price * 100.0 # 下落率
            decrease_rate_total[i] = decrease_rate
            if ( decrease_rate > 10.0 )
                # 投資額を計算して，その分の株式を購入
                amount = (((decrease_rate - 8)^1.1) + 12) * 0.2
                if ( amount > hold_cash[i] ) # 保有現金が不足した場合，保有現金分しか買わない
                    amount = hold_cash[i] / (1 + fee)
                end
                hold_stock[i] = amount / prices[i]
                hold_cash[i] -= amount * (1 + fee)
            end
        end
    end

    return (hold_stock, hold_cash)
end

hold_stocks = zeros(size(spxl_30y))
hold_cash = zeros(size(spxl_30y))
for n in 1:data_num
    prices = spxl_30y[:,n]
    timestamp = spxl.timestamp
    fee = 0.45 / 100 
    (stock, cash) = additional(prices, purchases, timestamp, fee)
    hold_stocks[:,n] = stock
    hold_cash[:,n] = cash
end

# 購入株式数を積算して保有株式数とする
stocks_spxl = zeros(size(spxl_30y)) 
for n in 1:data_num
    stocks_spxl[:,n] = accumulate(+, hold_stocks[:,n])
end

# 保有株式数にその時の価格を掛け算して，資産額を算出
assets_spxl = copy(stocks_spxl)
for c = 1:data_num
    assets_spxl[:,c] .*= spxl_30y[:,c]
end

# 5パーセンタイル，50パーセンタイル, 95パーセンタイルを計算してプロット
quan_assets = zeros(data_len, 3)
for r in 1:data_len
    quan_assets[r,:] = quantile(assets_spxl[r,:], [0.05, 0.5, 0.95])
end
quan_cash = zeros(data_len, 3)
for r in 1:data_len
    quan_cash[r,:] = quantile(hold_cash[r,:], [0.05, 0.5, 0.95])
end
# quan_cashが0だと対数グラフで描画できないので1万円足す
quan_cash .+= 1 

#= 
plot( (1:data_len) .* 30 / data_len, quan_assets[:,3], label="金融資産額" * labels[3], linecolor=:blue, xlabel="年", ylabel="資産額[万円]", yscale=:log10)
plot!( (1:data_len) .* 30 / data_len, quan_assets[:,2], label="金融資産額" * labels[2], linecolor=:green)
plot!( (1:data_len) .* 30 / data_len, quan_assets[:,1], label="金融資産額" * labels[1], linecolor=:red)
plot!( (1:data_len) .* 30 / data_len, quan_cash[:,3], label="現金" * labels[3], linestyle=:dot, linecolor=:blue)
plot!( (1:data_len) .* 30 / data_len, quan_cash[:,2], label="現金" * labels[2], linestyle=:dot, linecolor=:green)
plot!( (1:data_len) .* 30 / data_len, quan_cash[:,1], label="現金" * labels[1], linestyle=:dot, linecolor=:red) =#
plot( (1:data_len) .* 30 / data_len, quan_assets[:,3] .+ quan_cash[:,3], label="合計" * labels[3], linecolor=:blue, yscale=:log10)
plot!( (1:data_len) .* 30 / data_len, quan_assets[:,2] .+ quan_cash[:,2], label="合計" * labels[2], linecolor=:green)
plot!( (1:data_len) .* 30 / data_len, quan_assets[:,1] .+ quan_cash[:,1], label="合計" * labels[1], linecolor=:red)
plot!( (1:data_len) .* 30 / data_len, total_purchases, label=labels[4], linecolor=:black)
savefig("SPXL_30y_5parcentile_assets_タイミング投資.png")

# 成績の計算
for i = 3:-1:1
    print(labels[i] * ": " * string((quan_assets[end, i] * (1 - 0.20315) + quan_cash[end,i]) / total_purchases[end])[1:4] * "倍\n")
end
(quan_assets[2513, 2] + quan_cash[2513, 2]) / total_purchases[2513]
for i = 3:-1:1
    print(labels[i] * ": " * string((quan_assets[end, i] * (1 - 0.20315) + quan_cash[end,i]))[1:7] * "万円\n")
end
quan_assets[2513, 2] + quan_cash[2513, 2]

print("下位5%の最大下落率[%]:" * string(100 - minimum((quan_assets[:,1] .+ quan_cash[:,1]) ./ total_purchases) * 100)[1:4])
