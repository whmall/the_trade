# TheTrade

This project rocks and uses MIT-LICENSE.


## 核心模型
 
* good_type / good_id
 
可进行售卖，出租的实体，将其关联 good 即可处理。`Good`模型会处理涉及由可交易产生的信息，比如价格、促销方式等。

* Buyer

#### 流程  
CartItem -> Order(OrderItem) <=> Payment


QuotationItem -> Order(OrderItem)
  
```
└ Promote
```
  
#### 集成商品编辑信息
```erb

```
  
OrderItem <=> Shipment
         
* Buyer
 
 
* Provider

#### Dev 
-[] support process to order by cart item ids



### 依赖
[default_form](https://github.com/qinmingyuan/default_form)

[default_where](https://github.com/qinmingyuan/default_where)

 