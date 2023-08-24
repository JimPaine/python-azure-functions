import unittest

from unittest.mock import MagicMock, patch
from math_functions import add_function, add

class MathTests(unittest.TestCase):

    @patch('azure.functions.EventHubEvent.__new__')
    def test_add_function(self, hub):
        # Arrange
        payload = str.encode("{\"x\":1,\"y\":2}", 'utf-8')
        hub.get_body = MagicMock(return_value=payload) # mock response from event hub event
        func = add_function.build().get_user_function() # get the function to be tested

        func(hub) # Act

        self.assertLogs("1 + 2 = 3", level='INFO') # Assert

    def test_add(self):
        # Arrange
        x = 5
        y = 7

        z = add(x, y) # Act

        self.assertEqual(z, 12) # Assert


if __name__ == '__main__':
    unittest.main()