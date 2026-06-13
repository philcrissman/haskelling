module Guards where

gradeLetter :: Int -> Char
gradeLetter score
  | score >= 90 = 'A'
  | score >= 80 = 'B'
  | score >= 70 = 'C'
  | otherwise   = 'F'
