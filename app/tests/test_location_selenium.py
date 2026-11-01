import time

from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.firefox.options import Options

def create_driver():
    options = Options()
    driver = webdriver.Firefox(options=options)
    driver.maximize_window()
    return driver

def test_valid_location():

    driver = create_driver()
    try:
        driver.get("http://54.198.77.62")

        print("Website opened")
        time.sleep(2)

        search_bar = driver.find_element(By.NAME, "location")

        print("Search bar found")
        time.sleep(2)

        search_bar.send_keys("London,United Kingdom")

        print("Typed city")
        time.sleep(2)

        search_bar.send_keys(Keys.ENTER)

        print("Search submitted")
        time.sleep(5)

        assert "London" in driver.page_source

        print("Positive test passed")

        time.sleep(10)

    finally:
        driver.quit()


def test_invalid_location():

    driver = create_driver()

    try:
        driver.get("http://54.198.77.62")

        print("Website opened")
        time.sleep(2)

        search_bar = driver.find_element(By.NAME, "location")

        print("Search bar found")
        time.sleep(2)

        search_bar.send_keys("abcdefghi")

        print("Typed invalid city")
        time.sleep(2)

        search_bar.send_keys(Keys.ENTER)

        print("Search submitted")
        time.sleep(5)

        assert "no locations found" in driver.page_source.lower()

        print("Negative test passed")

        time.sleep(10)

    finally:
        driver.quit()