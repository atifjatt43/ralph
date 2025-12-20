# AssociationMetadata

`class`

*Defined in [src/ralph/associations.cr:20](https://github.com/watzon/ralph/blob/main/src/ralph/associations.cr#L20)*

Association metadata storage

## Constructors

### `.new(name : String, class_name : String, foreign_key : String, type : Symbol, table_name : String, through : String | Nil = nil, source : String | Nil = nil, primary_key : String = "id", dependent : DependentBehavior = DependentBehavior::None, class_name_override : Bool = false, foreign_key_override : Bool = false, primary_key_override : Bool = false, polymorphic : Bool = false, as_name : String | Nil = nil, counter_cache : String | Nil = nil, touch : String | Nil = nil, inverse_of : String | Nil = nil)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/associations.cr#L39)*

---

