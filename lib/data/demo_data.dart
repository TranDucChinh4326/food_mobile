import '../models/food_item.dart';

const demoFoods = <FoodItem>[
  FoodItem(
    id: 1,
    name: 'Cơm gà nướng',
    category: 'Cơm',
    price: 45000,
    oldPrice: 52000,
    imageUrl: 'https://images.unsplash.com/photo-1603133872878-684f208fb84b?auto=format&fit=crop&w=900&q=85',
    rating: 4.9,
    sold: 128,
  ),
  FoodItem(
    id: 2,
    name: 'Mì xào hải sản',
    category: 'Mì',
    price: 48000,
    imageUrl: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=900&q=85',
    rating: 4.8,
    sold: 96,
  ),
  FoodItem(
    id: 3,
    name: 'Cơm chiên hải sản',
    category: 'Cơm',
    price: 55000,
    imageUrl: 'https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=900&q=85',
    rating: 4.7,
    sold: 84,
  ),
  FoodItem(
    id: 4,
    name: 'Trà đào cam sả',
    category: 'Nước uống',
    price: 28000,
    oldPrice: 35000,
    imageUrl: 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?auto=format&fit=crop&w=900&q=85',
    rating: 4.9,
    sold: 157,
  ),
];

const foodCategories = ['Tất cả', 'Cơm', 'Mì', 'Nước uống', 'Bánh ngọt'];
