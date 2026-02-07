// Catch2-based tests for Calculator
#define CATCH_CONFIG_FAST_COMPILE
#include <catch2/catch_test_macros.hpp>

#include "backend/Calculator.h"

using namespace backend;

TEST_CASE("Addition works", "add") {
    Calculator calc;
    REQUIRE(calc.add(2, 3) == 5);
    REQUIRE(calc.add(-1, 1) == 0);
}

TEST_CASE("Subtraction works", "subtract") {
    Calculator calc;
    REQUIRE(calc.subtract(5, 3) == 2);
    REQUIRE(calc.subtract(0, 5) == -5);
}

TEST_CASE("Multiplication works", "multiply") {
    Calculator calc;
    REQUIRE(calc.multiply(3, 4) == 12);
    REQUIRE(calc.multiply(-2, 3) == -6);
}

TEST_CASE("Division works", "divide") {
    Calculator calc;
    REQUIRE(calc.divide(10, 2) == 5);
    REQUIRE(calc.divide(7, 2) == 3);
}

TEST_CASE("Division by zero throws", "divide_zero") {
    Calculator calc;
    REQUIRE_THROWS_AS(calc.divide(10, 0), std::invalid_argument);
}
